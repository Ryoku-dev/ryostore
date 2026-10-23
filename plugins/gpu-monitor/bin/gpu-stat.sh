#!/usr/bin/env bash
# gpu-stat.sh [gpu] [top]
#   gpu: "auto" (default), or a card name (card1), PCI slot (0000:03:00.0) or
#        driver (i915, xe, amdgpu, nvidia) to pick one GPU.
#   top: "top" also lists per-process GPU use where that costs extra (AMD, NVIDIA).
# Prints one snapshot as key=value lines, then per-process lines:
#   p<TAB>pid<TAB>render<TAB>media<TAB>total<TAB>comm   (cumulative fdinfo counters)
#   q<TAB>pid<TAB>percent<TAB>comm                      (NVIDIA, already a percentage)
# Reads sysfs and /proc only (plus nvidia-smi on NVIDIA). No root, writes nothing.
set -u
want=${1:-auto}
top=${2:-}

rd() { [[ -r "$1" ]] && cat "$1" 2>/dev/null; }

# ── discover GPUs ────────────────────────────────────────────────────────────
cards=(); drivers=(); pcis=()
for d in /sys/class/drm/card[0-9]*; do
  [[ -e "$d" ]] || continue
  [[ "$(basename "$d")" == *-* ]] && continue          # connectors (card1-eDP-1)
  drv=$(readlink -f "$d/device/driver" 2>/dev/null) || continue
  [[ -n "$drv" ]] || continue
  cards+=("$d"); drivers+=("$(basename "$drv")"); pcis+=("$(basename "$(readlink -f "$d/device")")")
done
# NVIDIA without a DRM card (nvidia-drm modeset off): still usable via nvidia-smi.
if command -v nvidia-smi >/dev/null 2>&1 && [[ " ${drivers[*]:-} " != *" nvidia "* ]]; then
  cards+=(""); drivers+=("nvidia"); pcis+=("")
fi

pick=-1
if [[ "$want" != "auto" && -n "$want" ]]; then
  for i in "${!drivers[@]}"; do
    c=${cards[$i]##*/}
    if [[ "$c" == "$want" || "${drivers[$i]}" == "$want" || ( -n "${pcis[$i]}" && "${pcis[$i]}" == *"$want" ) ]]; then
      pick=$i; break
    fi
  done
fi
if (( pick < 0 )); then
  best=0
  for i in "${!drivers[@]}"; do
    case "${drivers[$i]}" in
      nvidia) s=40 ;;
      amdgpu)                                           # dGPU has real VRAM, an APU a small carve-out
        v=$(rd "${cards[$i]}/device/mem_info_vram_total")
        if [[ "$v" =~ ^[0-9]+$ ]] && (( v > 2147483648 )); then s=30; else s=20; fi ;;
      i915|xe) s=20 ;;
      *) s=0 ;;
    esac
    if (( s > best )); then best=$s; pick=$i; fi
  done
fi

echo "gpus=$(IFS=,; echo "${drivers[*]:-}")"
if (( pick < 0 )); then
  echo "ok=0"
  exit 0
fi

card=${cards[$pick]}; drv=${drivers[$pick]}; pci=${pcis[$pick]}
echo "ok=1"
echo "t=$(date +%s%3N)"
echo "driver=$drv"
echo "card=${card##*/}"
echo "pci=$pci"

# CPU package temperature, for integrated GPUs without their own sensor.
cpu_temp() {
  local h l n want_label
  for h in /sys/class/hwmon/hwmon*; do
    n=$(rd "$h/name")
    case "$n" in
      coretemp) want_label="Package id 0" ;;
      k10temp)  want_label="Tctl" ;;
      *) continue ;;
    esac
    for l in "$h"/temp*_label; do
      if [[ "$(rd "$l")" == "$want_label" ]]; then rd "${l%_label}_input"; return; fi
    done
  done
}

# Throttle reasons from a folder of reason_* / throttle_reason_* flags.
throttle_from() {   # $1 = dir, $2 = file prefix, $3 = status file
  local out="" f n
  [[ "$(rd "$1/$3")" == "1" ]] || { echo ""; return; }
  for f in "$1"/"$2"*; do
    n=${f##*/}; n=${n#"$2"}
    [[ "$n" == "status" ]] && continue
    [[ "$(rd "$f")" == "1" ]] && out+="${out:+,}$n"
  done
  echo "${out:-active}"
}

# Per-process engine counters from DRM fdinfo, for this driver and device only.
fdinfo_procs() {
  grep -H -E '^drm-(driver|pdev|client-id|engine-[a-z0-9_-]+|cycles-[a-z]+|total-cycles-[a-z]+):' \
    /proc/[0-9]*/fdinfo/* 2>/dev/null |
  awk -v want="$drv" -v pci="$pci" '
  function flush(   p, k) {
    if (file != "" && drv == want && cid != "" && (pdev == "" || pci == "" || pdev == pci)) {
      split(file, p, "/"); k = p[3] SUBSEP cid
      if (!(k in seen)) {
        seen[k] = 1; R[p[3]] += r; M[p[3]] += m
        if (tot > T[p[3]]) T[p[3]] = tot
      }
    }
  }
  {
    i = index($0, ":drm-"); if (i == 0) next
    f = substr($0, 1, i - 1)
    if (f != file) { flush(); file = f; drv = ""; pdev = ""; cid = ""; r = 0; m = 0; tot = 0 }
    split(substr($0, i + 1), a, /[ \t]+/)
    key = a[1]; sub(/:$/, "", key); v = a[2] + 0
    if (key == "drm-driver") drv = a[2]
    else if (key == "drm-pdev") pdev = a[2]
    else if (key == "drm-client-id") cid = a[2]
    else if (key ~ /^drm-engine-capacity-/) { e = substr(key, 21); if (e == "video" || e == "vcs") { if (v > cap) cap = v } }
    else if (key ~ /^drm-engine-/ && a[3] == "ns") {
      e = substr(key, 12)
      if (e == "render" || e == "gfx" || e == "compute") r += v
      else if (e == "video" || e == "video-enhance" || e == "dec" || e == "enc" || e ~ /^enc_/ || e == "jpeg") m += v
    }
    else if (key ~ /^drm-total-cycles-/) { if (v > tot) tot = v }
    else if (key ~ /^drm-cycles-/) {
      e = substr(key, 12)
      if (e == "rcs" || e == "ccs") r += v
      else if (e == "vcs" || e == "vecs") m += v
    }
  }
  END {
    flush()
    print "cap=" (cap > 0 ? cap : 1)
    for (pid in R) {
      c = ""; cf = "/proc/" pid "/comm"
      if ((getline c < cf) > 0) close(cf)
      printf "p\t%s\t%s\t%s\t%s\t%s\n", pid, R[pid], M[pid], T[pid], c
    }
  }'
}

case "$drv" in
  i915)
    g="$card/gt/gt0"
    if [[ -d "$g" ]]; then
      echo "act=$(rd "$g/rps_act_freq_mhz")";  echo "cur=$(rd "$g/rps_cur_freq_mhz")"
      echo "max=$(rd "$g/rps_RP0_freq_mhz")";  echo "min=$(rd "$g/rps_RPn_freq_mhz")"
      echo "rc6=$(rd "$g/rc6_residency_ms")"
      t0=$(throttle_from "$card/gt/gt0" throttle_reason_ throttle_reason_status)
      t1=$(throttle_from "$card/gt/gt1" throttle_reason_ throttle_reason_status)
      echo "throttle=${t0}${t0:+${t1:+,}}${t1}"
    else                                                 # older kernels: single-GT files
      echo "act=$(rd "$card/gt_act_freq_mhz")"; echo "cur=$(rd "$card/gt_cur_freq_mhz")"
      echo "max=$(rd "$card/gt_RP0_freq_mhz")"; echo "min=$(rd "$card/gt_RPn_freq_mhz")"
      echo "rc6=$(rd "$card/power/rc6_residency_ms")"
    fi
    echo "unit=ns"
    echo "temp=$(cpu_temp)"; echo "temp_src=pkg"
    fdinfo_procs
    ;;
  xe)
    f="$card/device/tile0/gt0/freq0"
    echo "act=$(rd "$f/act_freq")"; echo "cur=$(rd "$f/cur_freq")"
    echo "max=$(rd "$f/rp0_freq")"; echo "min=$(rd "$f/rpn_freq")"
    [[ -d "$f/throttle" ]] && echo "throttle=$(throttle_from "$f/throttle" reason_ status)"
    echo "unit=cycles"
    echo "temp=$(cpu_temp)"; echo "temp_src=pkg"
    fdinfo_procs
    ;;
  amdgpu)
    dev="$card/device"
    echo "busy=$(rd "$dev/gpu_busy_percent")"
    if [[ -r "$dev/pp_dpm_sclk" ]]; then
      awk '{ v = $2; sub(/[Mm][Hh][Zz].*/, "", v); v += 0
             if (NR == 1) mn = v; mx = v; if ($0 ~ /\*/) act = v }
           END { print "act=" act; print "min=" mn; print "max=" mx }' "$dev/pp_dpm_sclk"
    fi
    echo "vram_used=$(rd "$dev/mem_info_vram_used")"; echo "vram_total=$(rd "$dev/mem_info_vram_total")"
    t=""
    for h in "$dev"/hwmon/hwmon*; do t=$(rd "$h/temp1_input"); [[ -n "$t" ]] && break; done
    echo "temp=$t"; echo "temp_src=gpu"
    echo "unit=ns"
    [[ "$top" == "top" ]] && fdinfo_procs
    ;;
  nvidia)
    q=$(nvidia-smi --query-gpu=name,utilization.gpu,clocks.gr,clocks.max.gr,temperature.gpu,memory.used,memory.total \
          --format=csv,noheader,nounits 2>/dev/null | head -n 1)
    IFS=',' read -r name busy act max temp mu mt <<<"$q"
    trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; echo "${s%"${s##*[![:space:]]}"}"; }
    num() { local s; s=$(trim "$1"); [[ "$s" =~ ^[0-9]+(\.[0-9]+)?$ ]] && echo "$s"; }
    echo "name=$(trim "${name:-}")"
    echo "busy=$(num "${busy:-}")"; echo "act=$(num "${act:-}")"; echo "max=$(num "${max:-}")"
    tc=$(num "${temp:-}"); echo "temp=${tc:+$(( ${tc%.*} * 1000 ))}"; echo "temp_src=gpu"
    u=$(num "${mu:-}"); tt=$(num "${mt:-}")
    echo "vram_used=${u:+$(( ${u%.*} * 1048576 ))}"; echo "vram_total=${tt:+$(( ${tt%.*} * 1048576 ))}"
    if [[ "$top" == "top" ]]; then
      # pmon prints a "# gpu pid type sm ... command" header; find columns by name.
      nvidia-smi pmon -c 1 -s u 2>/dev/null | awk '
        /^# *gpu/ { sub(/^# */, ""); for (i = 1; i <= NF; i++) col[$i] = i; next }
        /^#/ { next }
        ("pid" in col) && ("sm" in col) {
          pid = $(col["pid"]); sm = $(col["sm"]); cmd = $NF
          if (pid ~ /^[0-9]+$/ && sm ~ /^[0-9]+$/) printf "q\t%s\t%s\t%s\n", pid, sm, cmd
        }'
    fi
    ;;
esac
exit 0
