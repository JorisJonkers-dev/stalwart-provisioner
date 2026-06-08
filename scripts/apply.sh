#!/bin/sh
# Reconcile a consumer-supplied Stalwart Provisioner v2 manifest against a
# running Stalwart server. The manifest owns the domain, accounts, DKIM intent,
# and password source references; this script owns only the shared reconcile
# behavior.
set -eu

: "${STALWART_URL:=http://127.0.0.1:8080}"
: "${STALWART_USER:=admin}"
: "${STALWART_PASSWORD:?STALWART_PASSWORD must be set}"
: "${STALWART_MANIFEST:=/etc/stalwart-provisioner/manifest.json}"
: "${PLAN_TEMPLATE:=/opt/stalwart-provisioner/plan.ndjson.tmpl}"
: "${STALWART_SCHEMA:=/opt/stalwart-provisioner/schema/schema.min.json}"
: "${STALWART_CLI_VERSION:=1.0.7}"
: "${APPLY_IDLE:=true}"

export STALWART_URL STALWART_USER STALWART_PASSWORD

install_cli() {
  command -v stalwart-cli >/dev/null 2>&1 && return

  arch="$(uname -m)"
  case "$arch" in
    x86_64) target=x86_64-unknown-linux-musl ;;
    aarch64) target=aarch64-unknown-linux-musl ;;
    *) echo "apply: unsupported arch: $arch" >&2; exit 1 ;;
  esac

  echo "apply: downloading stalwart-cli v${STALWART_CLI_VERSION} (${target})"
  curl -fsSL "https://github.com/stalwartlabs/cli/releases/download/v${STALWART_CLI_VERSION}/stalwart-cli-${target}.tar.xz" -o /tmp/cli.tar.xz
  tar -xJf /tmp/cli.tar.xz -C /tmp
  find /tmp -type f -name stalwart-cli -exec mv {} /usr/local/bin/stalwart-cli \;
  chmod +x /usr/local/bin/stalwart-cli
}

sc() {
  stalwart-cli "$@"
}

first_id() {
  sc query "$1" --json 2>/dev/null | jq -rs '.[0].id // empty'
}

id_by_name() {
  sc query "$1" --json 2>/dev/null | jq -rs --arg name "$2" 'map(select(.name == $name))[0].id // empty'
}

id_by_email() {
  sc query Account --json 2>/dev/null | jq -rs --arg email "$1" 'map(select(.emailAddress == $email))[0].id // empty'
}

validate_inputs() {
  stalwart-provisioner validate manifest --check-password-sources "$STALWART_MANIFEST"
  stalwart-provisioner validate plan --schema "$STALWART_SCHEMA" "$PLAN_TEMPLATE"
}

load_manifest_domain() {
  STALWART_DOMAIN="$(jq -r '.domain.name' "$STALWART_MANIFEST")"
  STALWART_HOSTNAME="$(jq -r '.domain.publicHostname' "$STALWART_MANIFEST")"
  export STALWART_DOMAIN STALWART_HOSTNAME
}

wait_ready() {
  echo "apply: waiting for ${STALWART_URL}/admin/ ..."
  i=0
  until curl -fsS -o /dev/null "${STALWART_URL}/admin/"; do
    i=$((i + 1))
    [ "$i" -gt 120 ] && { echo "apply: stalwart never became ready" >&2; exit 1; }
    sleep 2
  done
}

apply_initial_plan_if_needed() {
  if [ -n "$(id_by_name Domain "$STALWART_DOMAIN")" ]; then
    echo "apply: domain ${STALWART_DOMAIN} already exists; initial plan skipped"
    return
  fi

  plan_file="$(mktemp)"
  trap 'rm -f "$plan_file"' EXIT
  echo "apply: applying initial plan for ${STALWART_DOMAIN}"
  envsubst < "$PLAN_TEMPLATE" > "$plan_file"
  stalwart-provisioner validate plan --schema "$STALWART_SCHEMA" "$plan_file"
  sc apply --file "$plan_file"
}

reconcile_domain_settings() {
  domain_id="$1"
  jq -nc --arg hostname "$STALWART_HOSTNAME" --arg domain_id "$domain_id" \
    '{"@type":"update","object":"SystemSettings","value":{"defaultHostname":$hostname,"defaultDomainId":$domain_id}}' \
    | sc apply --file /dev/stdin
}

reconcile_dkim() {
  domain_id="$1"
  dkim="$(
    jq -c '
      (.dkim // {}) as $dkim
      | if (($dkim.enabled // false) == true) then
          if (($dkim.mode // "automatic") == "manual") then
            {"@type":"Manual"}
          else
            {"@type":"Automatic"}
            + (if (($dkim.algorithms // []) | length) > 0 then
                {algorithms:(($dkim.algorithms // []) | map({(.):true}) | add)}
              else {} end)
            + (if ($dkim.selectorTemplate? // "") != "" then {selectorTemplate:$dkim.selectorTemplate} else {} end)
            + (if $dkim.rotateAfterMillis? then {rotateAfter:$dkim.rotateAfterMillis} else {} end)
            + (if $dkim.retireAfterMillis? then {retireAfter:$dkim.retireAfterMillis} else {} end)
            + (if $dkim.deleteAfterMillis? then {deleteAfter:$dkim.deleteAfterMillis} else {} end)
          end
        else empty end
    ' "$STALWART_MANIFEST"
  )"

  [ -n "$dkim" ] || return
  echo "apply: reconciling DKIM management for ${STALWART_DOMAIN}"
  jq -nc --arg domain_id "$domain_id" --argjson dkim "$dkim" \
    '{"@type":"update","object":"Domain","id":$domain_id,"value":{"dkimManagement":$dkim}}' \
    | sc apply --file /dev/stdin
}

read_password_ref() {
  entry="$1"
  local_part="$2"

  env_name="$(printf '%s' "$entry" | jq -r '.passwordRef.envVar // empty')"
  if [ -n "$env_name" ]; then
    value="$(printenv "$env_name" || true)"
    [ -n "$value" ] || { echo "apply: password environment variable for ${local_part} is empty" >&2; return 1; }
    printf '%s' "$value"
    return
  fi

  file_path="$(printf '%s' "$entry" | jq -r '.passwordRef.file // empty')"
  [ -n "$file_path" ] || { echo "apply: ${local_part} has no supported password source" >&2; return 1; }
  [ -r "$file_path" ] || { echo "apply: password file for ${local_part} is unreadable" >&2; return 1; }
  value="$(tr -d '\r\n' < "$file_path")"
  [ -n "$value" ] || { echo "apply: password file for ${local_part} is empty" >&2; return 1; }
  printf '%s' "$value"
}

managed_account_count() {
  jq '.managedAccounts | length' "$STALWART_MANIFEST"
}

managed_account_at() {
  jq -c ".managedAccounts[$1]" "$STALWART_MANIFEST"
}

reconcile_account_credentials() {
  domain_id="$1"
  count="$(managed_account_count)"
  i=0
  while [ "$i" -lt "$count" ]; do
    entry="$(managed_account_at "$i")"
    i=$((i + 1))
    local_part="$(printf '%s' "$entry" | jq -r '.localPart')"
    password="$(read_password_ref "$entry" "$local_part")"
    fields="$(jq -nc --arg password "$password" '{credentials:{"0":{"@type":"Password","secret":$password}}}')"
    account_id="$(id_by_email "${local_part}@${STALWART_DOMAIN}")"

    if [ -z "$account_id" ]; then
      echo "apply: creating account ${local_part}@${STALWART_DOMAIN}"
      jq -nc --arg local_part "$local_part" --arg domain_id "$domain_id" --argjson fields "$fields" \
        '{"@type":"create","object":"Account","value":{"acct":({"@type":"User","name":$local_part,"domainId":$domain_id} + $fields)}}' \
        | sc apply --file /dev/stdin
    else
      echo "apply: updating account credentials for ${local_part}@${STALWART_DOMAIN}"
      jq -nc --arg account_id "$account_id" --argjson fields "$fields" \
        '{"@type":"update","object":"Account","id":$account_id,"value":$fields}' \
        | sc apply --file /dev/stdin
    fi
  done
}

account_alias_fields() {
  entry="$1"
  domain_id="$2"
  printf '%s' "$entry" | jq -c --arg domain_id "$domain_id" '
    (.aliases // [])
    | to_entries
    | map({(.key | tostring): {name:.value, domainId:$domain_id, enabled:true}})
    | add // {}
  '
}

account_group_fields() {
  entry="$1"
  groups="{}"
  for group in $(printf '%s' "$entry" | jq -r '.groups[]?'); do
    group_id="$(id_by_email "${group}@${STALWART_DOMAIN}")"
    [ -n "$group_id" ] || { echo "apply: group ${group}@${STALWART_DOMAIN} was declared but was not found" >&2; return 1; }
    groups="$(printf '%s' "$groups" | jq -c --arg group_id "$group_id" '. + {($group_id):true}')"
  done
  printf '%s' "$groups"
}

reconcile_account_metadata() {
  domain_id="$1"
  count="$(managed_account_count)"
  i=0
  while [ "$i" -lt "$count" ]; do
    entry="$(managed_account_at "$i")"
    i=$((i + 1))
    local_part="$(printf '%s' "$entry" | jq -r '.localPart')"
    has_aliases="$(printf '%s' "$entry" | jq -r 'has("aliases")')"
    has_groups="$(printf '%s' "$entry" | jq -r 'has("groups")')"
    [ "$has_aliases" = "true" ] || [ "$has_groups" = "true" ] || continue

    fields="{}"
    if [ "$has_aliases" = "true" ]; then
      aliases="$(account_alias_fields "$entry" "$domain_id")"
      fields="$(printf '%s' "$fields" | jq -c --argjson aliases "$aliases" '. + {aliases:$aliases}')"
    fi
    if [ "$has_groups" = "true" ]; then
      groups="$(account_group_fields "$entry")"
      fields="$(printf '%s' "$fields" | jq -c --argjson groups "$groups" '. + {memberGroupIds:$groups}')"
    fi

    account_id="$(id_by_email "${local_part}@${STALWART_DOMAIN}")"
    [ -n "$account_id" ] || { echo "apply: account ${local_part}@${STALWART_DOMAIN} was not found after credential reconcile" >&2; return 1; }
    echo "apply: updating account metadata for ${local_part}@${STALWART_DOMAIN}"
    jq -nc --arg account_id "$account_id" --argjson fields "$fields" \
      '{"@type":"update","object":"Account","id":$account_id,"value":$fields}' \
      | sc apply --file /dev/stdin
  done
}

write_dns_requirements() {
  manifest_output="$(jq -r '.dns.publicationOutputFile // empty' "$STALWART_MANIFEST")"
  output_file="${STALWART_DNS_REQUIREMENTS_FILE:-$manifest_output}"
  [ -n "$output_file" ] || return

  zone_data="$(sc query Domain --json 2>/dev/null | jq -rs --arg name "$STALWART_DOMAIN" 'map(select(.name == $name))[0].dnsZoneFile // empty')"
  if [ -z "$zone_data" ]; then
    echo "apply: DNS publication data is not available from Stalwart yet"
    return
  fi
  printf '%s\n' "$zone_data" > "$output_file"
  echo "apply: wrote DNS publication data to ${output_file}"
}

main() {
  install_cli
  validate_inputs
  load_manifest_domain
  wait_ready
  apply_initial_plan_if_needed

  domain_id="$(id_by_name Domain "$STALWART_DOMAIN")"
  [ -n "$domain_id" ] || { echo "apply: domain ${STALWART_DOMAIN} not found in the datastore" >&2; exit 1; }
  reconcile_domain_settings "$domain_id"
  reconcile_dkim "$domain_id"
  reconcile_account_credentials "$domain_id"
  reconcile_account_metadata "$domain_id"
  write_dns_requirements
  echo "apply: reconcile complete"

  if [ "$APPLY_IDLE" = "true" ]; then
    echo "apply: idling; restart the container to reconcile again"
    exec sleep infinity
  fi
}

main "$@"
