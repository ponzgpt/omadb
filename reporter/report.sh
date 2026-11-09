#!/usr/bin/env bash
# OmaDB reporter: rates how Omarchy runs on this machine and sends it to omadb.technoir.cloud.
#
#   curl -fsSL https://omadb.technoir.cloud/report | bash               # report
#   curl -fsSL https://omadb.technoir.cloud/report | bash -s -- --dry-run   # print the payload, send nothing
#
# Works on an installed Omarchy and from the live ISO (so failed installs count too).
# Never reads or sends serial numbers, MAC addresses, hostnames or usernames.
# The machine-id is hashed before it leaves this script. Nothing is sent without your "y".
set -uo pipefail

OMADB_URL=${OMADB_URL:-https://omadb.technoir.cloud}
ROOT=${OMADB_SYSROOT:-}   # tests point this at a fake /sys + /proc tree
DRY_RUN=0
[[ ${1:-} == "--dry-run" ]] && DRY_RUN=1

# ── tiny UI: gum when Omarchy has it, plain prompts when it doesn't (live ISO, other distros) ──
tty_ok() { [[ $DRY_RUN == 0 ]] && { : </dev/tty; } 2>/dev/null; }
say() { if command -v gum >/dev/null; then gum style --foreground 4 "$*"; else printf '\033[34m%s\033[0m\n' "$*"; fi; }
dim() { printf '\033[2m%s\033[0m\n' "$*"; }

choose() { # choose "question" option...  → prints the chosen option
  local q=$1; shift
  if command -v gum >/dev/null; then gum choose --header "$q" "$@" </dev/tty; return; fi
  local i=1 o reply
  printf '\n%s\n' "$q" >/dev/tty
  for o in "$@"; do printf '  %d) %s\n' "$i" "$o" >/dev/tty; i=$((i + 1)); done
  while read -rp "  → " reply </dev/tty; do
    [[ $reply =~ ^[0-9]+$ ]] && ((reply >= 1 && reply <= $#)) && { printf '%s\n' "${!reply}"; return; }
  done
}

confirm() { # confirm "question" → 0 on yes. Default is no.
  if command -v gum >/dev/null; then gum confirm --default=false "$1" </dev/tty; return; fi
  local reply; read -rp "$1 [y/N] " reply </dev/tty; [[ $reply =~ ^[yY]$ ]]
}

# ── helpers ──
rd() { local v; v=$(tr -d '\000' 2>/dev/null <"$ROOT$1") || return 0; v=${v//$'\n'/ }; v=${v#"${v%%[![:space:]]*}"}; printf '%s' "${v%"${v##*[![:space:]]}"}"; }
hex4() { local v=${1#0x}; v=${v,,}; printf '%s' "${v:0:4}"; }

json_str() {
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\t'/ }; s=${s//$'\n'/ }; s=${s//$'\r'/}
  s=$(printf '%s' "$s" | tr -d '\000-\037')
  printf '"%s"' "$s"
}

join_json() { local IFS=,; printf '[%s]' "$*"; }

# ── automatic collection ──
collect_dmi() {
  local f out=() k
  # Deliberately absent: product_serial, product_uuid, board_serial, chassis_serial.
  for k in sys_vendor product_name product_version product_family product_sku board_vendor board_name bios_vendor bios_version chassis_type; do
    out+=("\"$k\":$(json_str "$(rd /sys/class/dmi/id/$k)")")
  done
  local IFS=,; printf '{%s}' "${out[*]}"
}

collect_cpu() {
  local vendor family model name
  vendor=$(grep -m1 '^vendor_id' "$ROOT/proc/cpuinfo" 2>/dev/null | cut -d: -f2-)
  family=$(grep -m1 '^cpu family' "$ROOT/proc/cpuinfo" 2>/dev/null | cut -d: -f2-)
  model=$(grep -m1 '^model[[:space:]]*:' "$ROOT/proc/cpuinfo" 2>/dev/null | cut -d: -f2-)
  name=$(grep -m1 '^model name' "$ROOT/proc/cpuinfo" 2>/dev/null | cut -d: -f2-)
  [[ -z $name ]] && name=$(grep -m1 -iE '^(Hardware|CPU part)' "$ROOT/proc/cpuinfo" 2>/dev/null | cut -d: -f2-) # aarch64
  printf '{"vendor":%s,"family":%s,"model":%s,"name":%s,"arch":%s}' \
    "$(json_str "${vendor// /}")" "$(json_str "${family// /}")" "$(json_str "${model// /}")" \
    "$(json_str "${name# }")" "$(json_str "$(uname -m)")"
}

collect_devices() {
  local d out=() driver classes i line name vendor product
  for d in "$ROOT"/sys/bus/pci/devices/*; do
    [[ -r $d/vendor ]] || continue
    driver=""; [[ -L $d/driver ]] && driver=$(basename "$(readlink "$d/driver")")
    out+=("{\"bus\":\"pci\",\"vendor\":\"$(hex4 "$(<"$d/vendor")")\",\"device\":\"$(hex4 "$(<"$d/device")")\",\"class\":\"$(hex4 "$(<"$d/class")")\",\"driver\":$(json_str "$driver")}")
  done
  for d in "$ROOT"/sys/bus/usb/devices/*; do
    [[ -r $d/idVendor && ${d##*/} != usb* ]] || continue
    classes=$(cat "$d"/*:*/bInterfaceClass 2>/dev/null | sort -u | tr '\n' ' ')
    # Deliberately not read: $d/serial.
    out+=("{\"bus\":\"usb\",\"vendor\":\"$(hex4 "$(<"$d/idVendor")")\",\"device\":\"$(hex4 "$(<"$d/idProduct")")\",\"classes\":$(json_str "$(<"$d/bDeviceClass") $classes"),\"product\":$(json_str "$(cat "$d/product" 2>/dev/null)")}")
  done
  for i in "$ROOT"/proc/asound/card*/codec#*; do
    [[ -r $i ]] || continue
    name=$(grep -m1 '^Codec:' "$i" | cut -d: -f2-)
    vendor=$(grep -m1 '^Vendor Id:' "$i" | awk '{print $3}')
    [[ -n $vendor ]] && out+=("{\"bus\":\"hda\",\"vendor\":\"${vendor:2:4}\",\"device\":\"${vendor:6:4}\",\"name\":$(json_str "${name# }")}")
  done
  # Touchpads and keyboards from the input layer (i2c/PS2 parts never show up on PCI or USB).
  name=""; vendor=""; product=""
  while IFS= read -r line; do
    case $line in
      I:*) vendor=$(sed -n 's/.*Vendor=\([0-9a-f]*\).*/\1/p' <<<"$line"); product=$(sed -n 's/.*Product=\([0-9a-f]*\).*/\1/p' <<<"$line") ;;
      N:*) name=$(sed -n 's/^N: Name="\(.*\)"/\1/p' <<<"$line") ;;
      "") if [[ $name =~ [Tt]ouch[Pp]ad ]]; then
            out+=("{\"bus\":\"input\",\"kind\":\"touchpad\",\"vendor\":\"$vendor\",\"device\":\"$product\",\"name\":$(json_str "$name")}")
          fi
          name="" ;;
    esac
  done < <(cat "$ROOT/proc/bus/input/devices" 2>/dev/null; echo)
  join_json "${out[@]}"
}

collect_vainfo() {
  [[ -n $ROOT ]] && { printf '{"ran":false}'; return; }
  command -v vainfo >/dev/null || { printf '{"ran":false}'; return; }
  local out ok=false
  out=$(timeout 10 vainfo 2>&1) && grep -q 'VAEntrypointVLD' <<<"$out" && ok=true
  printf '{"ran":true,"ok":%s,"driver":%s}' "$ok" "$(json_str "$(grep -m1 'Driver version' <<<"$out" | cut -d: -f2-)")"
}

collect_fprintd() {
  [[ -n $ROOT ]] && return
  command -v fprintd-list >/dev/null || return
  timeout 5 fprintd-list "$(id -un)" 2>/dev/null | sed -n 's/.* on \(.*\) (.*/\1/p' | head -1
}

# Omarchy's own hardware predicates: which quirk profiles the installer recognises on this machine.
collect_omarchy_hw() {
  local p out=()
  [[ -n $ROOT ]] && { printf '[]'; return; }
  for p in laptop vm touchpad webcam fingerprint hybrid-gpu nvidia nvidia-gsp intel-ptl intel-sof apple-silicon \
    asus-rog asus-expertbook-b9406 asus-zenbook-ux5406aa framework16 surface dell-xps-haptic-touchpad \
    dell-xps-oled dell-xps13-dx13260-ptl dell-xps13-sidecar-amps; do
    command -v "omarchy-hw-$p" >/dev/null && timeout 3 "omarchy-hw-$p" >/dev/null 2>&1 && out+=("\"$p\"")
  done
  join_json "${out[@]}"
}

omarchy_version() {
  local v
  v=$(omarchy-version 2>/dev/null) && [[ -n $v ]] && { printf '%s' "$v"; return; }
  for f in "${OMARCHY_PATH:-/usr/share/omarchy}/version" "$HOME/.local/share/omarchy/version" /root/omarchy/version; do
    [[ -r $ROOT$f ]] && { rd "$f"; return; }
  done
  printf 'unknown'
}

machine_hash() {
  local id; id=$(rd /etc/machine-id)
  [[ -z $id ]] && id=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
  printf 'omadb:%s' "$id" | sha256sum | cut -c1-32
}

# ── subjective checklist ──
declare -A FEATURES=()
STATUS_OPTIONS=("works" "works after a fix" "partly" "broken" "didn't test")
to_status() {
  case $1 in
    "works") echo works ;; "works after a fix") echo works_after_fix ;; "partly") echo partial ;;
    "broken") echo broken ;; *) echo untested ;;
  esac
}
ask() { FEATURES[$1]=$(to_status "$(choose "$2" "${STATUS_OPTIONS[@]}")"); }

checklist() {
  local live=$1 gpus=$2 fp=$3
  if [[ $live == 1 ]]; then
    case $(choose "You're on the live ISO. How far did the install get?" "installed and boots fine" "installer failed" "installed, won't boot" "haven't installed yet") in
      "installed and boots fine") FEATURES[install_boot]=works ;;
      "installer failed" | "installed, won't boot") FEATURES[install_boot]=broken ;;
      *) FEATURES[install_boot]=untested ;;
    esac
  else
    FEATURES[install_boot]=works
  fi
  say "Core. Under a minute; skip what you haven't tried."
  ask display "Internal screen, incl. brightness keys"
  [[ -z ${FEATURES[gpu_accel]:-} ]] && ask gpu_accel "Video plays smoothly (hardware decode)"
  ask wifi "Wi-Fi connects and stays connected"
  ask audio "Speakers and built-in mic"
  ask suspend "Close the lid, open it: back in a few seconds?"
  ask touchpad "Touchpad, incl. gestures"
  ask keyboard "Keyboard, incl. backlight"
  confirm "Rate the extras too (bluetooth, webcam, battery, docks)?" || return 0
  ask bluetooth "Bluetooth"
  ask webcam "Webcam"
  [[ -n $fp ]] && ask fingerprint "Fingerprint reader"
  ask battery "Battery life and power profiles"
  ask fn_keys "Fn / media keys"
  ask usbc_display "External display over USB-C / Thunderbolt dock"
  ((gpus > 1)) && ask hybrid_gpu "Switching between the two GPUs"
  return 0
}

features_json() {
  local k out=()
  for k in "${!FEATURES[@]}"; do out+=("\"$k\":\"${FEATURES[$k]}\""); done
  local IFS=,; printf '{%s}' "${out[*]}"
}

# ── main ──
main() {
  local live=0 source=installed
  [[ -d $ROOT/run/archiso ]] && { live=1; source=live_iso; }

  if [[ $DRY_RUN == 0 ]] && ! tty_ok; then
    echo "OmaDB needs a terminal to ask a few questions. Run it from one, or add: bash -s -- --dry-run" >&2
    exit 1
  fi

  if [[ $DRY_RUN == 0 ]]; then
    say "OmaDB reporter: does Omarchy run on this machine?"
    dim "Script: $OMADB_URL/report. Nothing leaves this machine until you say y."
    if [[ $(choose "First:" "continue" "read the script first" "quit") != "continue" ]]; then
      echo "Read it with:  curl -fsSL $OMADB_URL/report | less"; exit 0
    fi
  fi

  local dmi cpu devices vainfo fp hw version channel gpus note=""
  dmi=$(collect_dmi); cpu=$(collect_cpu); devices=$(collect_devices)
  vainfo=$(collect_vainfo); fp=$(collect_fprintd); hw=$(collect_omarchy_hw)
  version=$(omarchy_version); channel=$(omarchy-version-channel 2>/dev/null | head -1)
  gpus=$(grep -o '"class":"03[0-9a-f]*"' <<<"$devices" | wc -l)

  if [[ $vainfo == *'"ok":true'* ]]; then FEATURES[gpu_accel]=works
  elif [[ $vainfo == *'"ok":false'* ]]; then FEATURES[gpu_accel]=broken; fi

  if [[ $DRY_RUN == 0 ]]; then
    checklist "$live" "$gpus" "$fp"
    if confirm "Add a one-line note (a fix you used, a quirk)?"; then
      read -rp "Note: " note </dev/tty
    fi
  fi

  local payload
  payload=$(printf '{"schema":1,"machine_hash":"%s","source":"%s","omarchy_version":%s,"channel":%s,"kernel":%s,"dmi":%s,"cpu":%s,"devices":%s,"vainfo":%s,"fprintd":%s,"omarchy_hw":%s,"features":%s,"note":%s}' \
    "$(machine_hash)" "$source" "$(json_str "$version")" "$(json_str "$channel")" "$(json_str "$(uname -r)")" \
    "$dmi" "$cpu" "$devices" "$vainfo" "$(json_str "$fp")" "$hw" "$(features_json)" "$(json_str "$note")")

  if [[ $DRY_RUN == 1 ]]; then printf '%s\n' "$payload"; exit 0; fi

  say "This is everything that will be sent:"
  if command -v jq >/dev/null; then jq . <<<"$payload"; else printf '%s\n' "$payload"; fi
  confirm "Send it to $OMADB_URL?" || { echo "Nothing sent."; exit 0; }

  local response
  if ! response=$(curl -fsS --max-time 20 -H 'Content-Type: application/json' --data-binary @- "$OMADB_URL/reports" <<<"$payload" 2>&1); then
    local saved=${TMPDIR:-/tmp}/omadb-report.json
    printf '%s\n' "$payload" >"$saved"
    echo "Couldn't reach OmaDB ($response). Saved to $saved. Once online:"
    echo "  curl -fsS -H 'Content-Type: application/json' --data-binary @$saved $OMADB_URL/reports"
    exit 1
  fi
  card "$response"
}

field() { sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" <<<"$2"; }

card() {
  local tier machine url first
  tier=$(field tier "$1"); machine=$(field machine "$1"); url=$(field url "$1")
  [[ $1 == *'"first_on_sku":true'* ]] && first=1 || first=0
  printf '\n┌─ omadb ──────────────────────────────────────\n'
  printf '│ ● %s\n│ %s\n' "${tier^^}" "$machine"
  ((first)) && printf '│ You just verified this model. First report on this exact SKU.\n'
  printf '│ %s\n└──────────────────────────────────────────────\n' "$url"
}

main "$@"
