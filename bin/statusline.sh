#!/bin/bash
set -f

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ── Colors ──────────────────────────────────────────────
blue='\033[38;2;0;153;255m'
green='\033[38;2;0;175;80m'
cyan='\033[38;2;86;182;194m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
orange='\033[38;2;255;176;85m'
white='\033[38;2;220;220;220m'
dim='\033[2m'
reset='\033[0m'

sep=" ${dim}│${reset} "

# ── Helpers ──────────────────────────────────────────────
format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.1fm\", $num / 1000000}"
    elif [ "$num" -ge 1000 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.0fk\", $num / 1000}"
    else
        printf "%d" "$num"
    fi
}

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ] 2>/dev/null; then printf "$red"
    elif [ "$pct" -ge 70 ] 2>/dev/null; then printf "$yellow"
    elif [ "$pct" -ge 50 ] 2>/dev/null; then printf "$orange"
    else printf "$green"
    fi
}

build_bar() {
    local pct=$1
    local width=${2:-10}
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100

    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color
    bar_color=$(color_for_pct "$pct")

    local filled_str="" empty_str=""
    for ((i=0; i<filled; i++)); do filled_str+="●"; done
    for ((i=0; i<empty; i++)); do empty_str+="○"; done

    printf "${bar_color}${filled_str}${dim}${empty_str}${reset}"
}

iso_to_epoch() {
    local iso_str="$1"
    local epoch

    epoch=$(date -d "${iso_str}" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then echo "$epoch"; return 0; fi

    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"

    if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]] || [[ "$iso_str" == *"-00:00"* ]]; then
        epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    else
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    fi

    [ -n "$epoch" ] && echo "$epoch" && return 0
    return 1
}

# ── Extract JSON data ─────────────────────────────────────
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
model_id=$(echo "$input" | jq -r '.model.id // ""')
cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)

size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
[ "$size" -eq 0 ] 2>/dev/null && size=200000

input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
output_tokens=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

current=$(( input_tokens + cache_create + cache_read ))
pct_used=0
[ "$size" -gt 0 ] 2>/dev/null && pct_used=$(( current * 100 / size ))

total_label=$(format_tokens "$size")

# ── Session duration ──────────────────────────────────────
session_duration=""
session_start=$(echo "$input" | jq -r '.session.start_time // empty')
if [ -n "$session_start" ] && [ "$session_start" != "null" ]; then
    start_epoch=$(iso_to_epoch "$session_start")
    if [ -n "$start_epoch" ]; then
        now_epoch=$(date +%s)
        elapsed=$(( now_epoch - start_epoch ))
        if [ "$elapsed" -ge 3600 ] 2>/dev/null; then
            session_duration="$(( elapsed / 3600 ))h$(( (elapsed % 3600) / 60 ))m"
        elif [ "$elapsed" -ge 60 ] 2>/dev/null; then
            session_duration="$(( elapsed / 60 ))m"
        else
            session_duration="${elapsed}s"
        fi
    fi
fi

# ── Cost estimate ─────────────────────────────────────────
case "$model_id" in
    *"claude-opus-4"*)
        input_price=15.00; output_price=75.00
        cache_write_price=18.75; cache_read_price=1.50 ;;
    *"claude-sonnet-4"*|*"claude-3-7-sonnet"*|*"claude-3-5-sonnet"*)
        input_price=3.00; output_price=15.00
        cache_write_price=3.75; cache_read_price=0.30 ;;
    *"claude-haiku"*|*"claude-3-5-haiku"*)
        input_price=0.80; output_price=4.00
        cache_write_price=1.00; cache_read_price=0.08 ;;
    *)
        input_price=3.00; output_price=15.00
        cache_write_price=3.75; cache_read_price=0.30 ;;
esac

cost=$(awk -v it="$input_tokens" -v ot="$output_tokens" -v cc="$cache_create" -v cr="$cache_read" \
           -v ip="$input_price" -v op="$output_price" -v cp="$cache_write_price" -v rp="$cache_read_price" \
           'BEGIN {
               total = (it * ip + ot * op + cc * cp + cr * rp) / 1000000
               if (total >= 0.01) printf "%.2f", total
               else if (total >= 0.001) printf "%.3f", total
               else printf "%.4f", total
           }')

# ── Git info ──────────────────────────────────────────────
git_branch=""
git_dirty=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
        git_dirty="*"
    fi
fi

# ── Line 1 ────────────────────────────────────────────────
bar=$(build_bar "$pct_used")
pct_color=$(color_for_pct "$pct_used")

line1="${blue}${model_name}${reset}"
line1+="${sep}${cyan}${cwd##*/}${reset}"

if [ -n "$git_branch" ]; then
    line1+=" ${dim}(${reset}${green}${git_branch}${red}${git_dirty}${dim})${reset}"
fi

line1+="${sep}${bar} ${pct_color}${pct_used}%${reset}${dim}/${reset}${white}${total_label}${reset}"

if [ -n "$session_duration" ]; then
    line1+="${sep}${dim}⏱${reset} ${white}${session_duration}${reset}"
fi

if [ -n "$cost" ] && [ "$cost" != "0.0000" ]; then
    line1+="${sep}${green}\$${cost}${reset}"
fi

# ── Lines 2-3: context window split into current/weekly approximation ────
# Since we have no API, we show the context window usage in two ways:
# current = what's used this turn (input_tokens only, not cache)
# total   = full context usage including cache

current_pct=0
[ "$size" -gt 0 ] 2>/dev/null && current_pct=$(( input_tokens * 100 / size ))

total_pct=$pct_used

current_bar=$(build_bar "$current_pct")
total_bar=$(build_bar "$total_pct")
current_pct_color=$(color_for_pct "$current_pct")
total_pct_color=$(color_for_pct "$total_pct")

line2="${white}context${reset} ${current_bar} ${current_pct_color}$(printf "%3d" "$current_pct")%${reset}  ${dim}input tokens${reset}"
line3="${white}total  ${reset} ${total_bar} ${total_pct_color}$(printf "%3d" "$total_pct")%${reset}  ${dim}incl. cache${reset}"

# ── Output ────────────────────────────────────────────────
printf "%b\n\n%b\n%b\n" "$line1" "$line2" "$line3"
