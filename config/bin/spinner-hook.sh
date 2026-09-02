#!/usr/bin/env bash
# spinner-hook.sh - Handles spinner animation for starship prompt
# Source this file in your .zshrc or .bashrc

# Initialize spinner state
_spinner_frame=0
_spinner_file="/tmp/starship-spinner"

# Function to increment spinner frame
_spinner_increment() {
    _spinner_frame=$(( (_spinner_frame + 1) % 10 ))
    echo "$_spinner_frame" > "$_spinner_file"
}

# Function to clear spinner
_spinner_clear() {
    rm -f "$_spinner_file"
}

# For zsh
if [ -n "$ZSH_VERSION" ]; then
    # precmd is called before each prompt is displayed
    _starship_precmd() {
        _spinner_clear
    }

    # preexec is called after a command is entered but before it executes
    _starship_preexec() {
        _spinner_increment &
        _spinner_pid=$!
        # Start background spinner update
        while kill -0 "$_spinner_pid" 2>/dev/null; do
            _spinner_increment
            sleep 0.1
        done &
        _spinner_loop_pid=$!
    }

    # Add hooks
    precmd_functions+=(_starship_precmd)
    preexec_functions+=(_starship_preexec)

# For bash
elif [ -n "$BASH_VERSION" ]; then
    # precmd is called before each prompt is displayed
    _starship_precmd() {
        _spinner_clear
    }

    # preexec is called after a command is entered but before it executes
    _starship_preexec() {
        _spinner_increment &
        _spinner_pid=$!
        # Start background spinner update
        while kill -0 "$_spinner_pid" 2>/dev/null; do
            _spinner_increment
            sleep 0.1
        done &
        _spinner_loop_pid=$!
    }

    # Add hooks using PROMPT_COMMAND
    if [ -z "$PROMPT_COMMAND" ]; then
        PROMPT_COMMAND="_starship_precmd"
    else
        PROMPT_COMMAND="_starship_precmd; $PROMPT_COMMAND"
    fi

    # Use DEBUG trap for preexec
    trap '_starship_preexec' DEBUG
fi
