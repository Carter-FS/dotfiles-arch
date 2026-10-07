#!/bin/bash
# Pomodoro timer for waybar.
#   status   - JSON status payload
#   toggle   - left click on timer (start / pause / resume)
#   skip     - skip current phase
#   reset    - clear session
#   settings - walker-based menu to edit durations

STATE_DIR="$HOME/.cache/waybar-pomodoro"
STATE_FILE="$STATE_DIR/state"
CONFIG_DIR="$HOME/.config/waybar"
CONFIG_FILE="$CONFIG_DIR/pomodoro.conf"
mkdir -p "$STATE_DIR" "$CONFIG_DIR"

# Defaults (minutes); overridden by CONFIG_FILE if present.
WORK_MIN=25
SHORT_BREAK_MIN=5
LONG_BREAK_MIN=15
LONG_BREAK_EVERY=4
SOUND_ENABLED=true

load_config() {
    [[ -f "$CONFIG_FILE" ]] && . "$CONFIG_FILE"
    WORK=$((WORK_MIN * 60))
    SHORT_BREAK=$((SHORT_BREAK_MIN * 60))
    LONG_BREAK=$((LONG_BREAK_MIN * 60))
}

save_config() {
    cat >"$CONFIG_FILE" <<EOF
WORK_MIN=$WORK_MIN
SHORT_BREAK_MIN=$SHORT_BREAK_MIN
LONG_BREAK_MIN=$LONG_BREAK_MIN
LONG_BREAK_EVERY=$LONG_BREAK_EVERY
SOUND_ENABLED=$SOUND_ENABLED
EOF
}

play_sound() {
    [[ "$SOUND_ENABLED" == "true" ]] || return 0
    canberra-gtk-play -i "$1" >/dev/null 2>&1 &
}

# State format: phase|end_ts|cycle|paused_remaining
# phase: idle | work | break | longbreak
# end_ts == 0 means paused; paused_remaining holds seconds left.
read_state() {
    if [[ -f "$STATE_FILE" ]]; then
        IFS='|' read -r PHASE END CYCLE PAUSED <"$STATE_FILE"
    fi
    PHASE="${PHASE:-idle}"
    END="${END:-0}"
    CYCLE="${CYCLE:-0}"
    PAUSED="${PAUSED:-0}"
}

write_state() {
    printf '%s|%s|%s|%s\n' "$PHASE" "$END" "$CYCLE" "$PAUSED" >"$STATE_FILE"
}

duration_for() {
    case "$1" in
        work) echo "$WORK" ;;
        break) echo "$SHORT_BREAK" ;;
        longbreak) echo "$LONG_BREAK" ;;
        *) echo 0 ;;
    esac
}

start_phase() {
    PHASE="$1"
    local dur
    dur=$(duration_for "$PHASE")
    END=$(( $(date +%s) + dur ))
    PAUSED=0
}

advance() {
    if [[ "$PHASE" == "work" ]]; then
        CYCLE=$((CYCLE + 1))
        play_sound complete
        if (( CYCLE % LONG_BREAK_EVERY == 0 )); then
            start_phase longbreak
            notify-send -u low "Pomodoro" "Long break - $LONG_BREAK_MIN min"
        else
            start_phase break
            notify-send -u low "Pomodoro" "Short break - $SHORT_BREAK_MIN min"
        fi
    else
        play_sound bell
        start_phase work
        notify-send -u normal "Pomodoro" "Back to work - $WORK_MIN min"
    fi
}

cmd_status() {
    read_state
    local now remaining text class tooltip
    now=$(date +%s)

    if [[ "$PHASE" == "idle" ]]; then
        text="󰔛"
        class="idle"
        tooltip="Pomodoro idle - click to start"
    elif [[ "$END" == "0" ]]; then
        remaining="$PAUSED"
        text=$(printf "󰔛 %d:%02d" $((remaining / 60)) $((remaining % 60)))
        class="paused"
        tooltip=$(printf "Paused (%s) - completed cycles: %d" "$PHASE" "$CYCLE")
    else
        remaining=$(( END - now ))
        while (( remaining <= 0 )); do
            advance
            now=$(date +%s)
            remaining=$(( END - now ))
        done
        write_state
        text=$(printf "󰔛 %d:%02d" $((remaining / 60)) $((remaining % 60)))
        class="$PHASE"
        case "$PHASE" in
            work) tooltip=$(printf "Working - cycle %d" $((CYCLE + 1))) ;;
            break) tooltip="Short break" ;;
            longbreak) tooltip="Long break" ;;
        esac
    fi

    jq -cn --arg text "$text" --arg class "$class" --arg tooltip "$tooltip" \
        '{text: $text, class: $class, tooltip: $tooltip}'
}

cmd_toggle() {
    read_state
    local now
    now=$(date +%s)
    if [[ "$PHASE" == "idle" ]]; then
        CYCLE=0
        start_phase work
    elif [[ "$END" == "0" ]]; then
        END=$(( now + PAUSED ))
        PAUSED=0
    else
        PAUSED=$(( END - now ))
        (( PAUSED < 0 )) && PAUSED=0
        END=0
    fi
    write_state
}

cmd_reset() {
    PHASE="idle"; END=0; CYCLE=0; PAUSED=0
    write_state
}

cmd_skip() {
    read_state
    if [[ "$PHASE" == "idle" ]]; then
        CYCLE=0
        start_phase work
    else
        advance
    fi
    write_state
}

walker_pick() {
    walker --dmenu --placeholder "$1" 2>/dev/null
}

prompt_minutes() {
    local label="$1" current="$2" choice
    choice=$(printf "5\n10\n15\n20\n25\n30\n45\n60\n90\n" | walker_pick "$label (current: $current min)")
    [[ -z "$choice" ]] && return 1
    [[ "$choice" =~ ^[0-9]+$ ]] || return 1
    echo "$choice"
}

cmd_settings() {
    local menu choice sound_label
    sound_label="Sounds: on"
    [[ "$SOUND_ENABLED" == "true" ]] || sound_label="Sounds: off"
    menu=$(printf 'Work: %d min\nShort break: %d min\nLong break: %d min\nLong break every: %d cycles\n%s\nTest sound\nReset to defaults' \
        "$WORK_MIN" "$SHORT_BREAK_MIN" "$LONG_BREAK_MIN" "$LONG_BREAK_EVERY" "$sound_label")
    choice=$(printf '%s\n' "$menu" | walker_pick "Pomodoro settings")
    case "$choice" in
        Work:*)
            v=$(prompt_minutes "Work duration" "$WORK_MIN") && WORK_MIN="$v" ;;
        "Short break:"*)
            v=$(prompt_minutes "Short break" "$SHORT_BREAK_MIN") && SHORT_BREAK_MIN="$v" ;;
        "Long break:"*)
            v=$(prompt_minutes "Long break" "$LONG_BREAK_MIN") && LONG_BREAK_MIN="$v" ;;
        "Long break every:"*)
            v=$(printf '2\n3\n4\n5\n6\n8\n' | walker_pick "Cycles before long break (current: $LONG_BREAK_EVERY)")
            [[ "$v" =~ ^[0-9]+$ ]] && LONG_BREAK_EVERY="$v" ;;
        "Sounds:"*)
            if [[ "$SOUND_ENABLED" == "true" ]]; then SOUND_ENABLED=false; else SOUND_ENABLED=true; fi ;;
        "Test sound")
            SOUND_ENABLED=true play_sound complete; return 0 ;;
        "Reset to defaults")
            WORK_MIN=25; SHORT_BREAK_MIN=5; LONG_BREAK_MIN=15; LONG_BREAK_EVERY=4; SOUND_ENABLED=true ;;
        *) return 0 ;;
    esac
    save_config
    notify-send -u low "Pomodoro" "Settings saved"
}

load_config

case "${1:-status}" in
    status)   cmd_status ;;
    toggle)   cmd_toggle ;;
    reset)    cmd_reset ;;
    skip)     cmd_skip ;;
    settings) cmd_settings ;;
    *) echo "usage: $0 {status|toggle|reset|skip|settings}" >&2; exit 2 ;;
esac
