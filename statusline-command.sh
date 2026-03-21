#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract values
model_name=$(echo "$input" | jq -r '.model.display_name')
model_id=$(echo "$input" | jq -r '.model.id')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
output_style=$(echo "$input" | jq -r '.output_style.name')
usage=$(echo "$input" | jq '.context_window.current_usage')

# Build status line components
status_parts=()

# Add model name
status_parts+=("$model_name")

# Add output style if not default
if [ "$output_style" != "default" ] && [ "$output_style" != "null" ] && [ -n "$output_style" ]; then
    status_parts+=("[$output_style]")
fi

# Add current directory (basename only)
dir_name=$(basename "$cwd")
status_parts+=("in $dir_name")

# Check if we're in a "real" project directory (not home or root)
is_project_dir() {
    local dir="$1"
    # Skip home directories and root
    if [ "$dir" = "$HOME" ] || [ "$dir" = "/" ] || [ "$dir" = "/Users" ]; then
        return 1
    fi
    # Check if it's a git repo or has project files
    if [ -d "$dir/.git" ] || [ -f "$dir/package.json" ] || [ -f "$dir/Cargo.toml" ] || \
       [ -f "$dir/go.mod" ] || [ -f "$dir/pyproject.toml" ] || [ -f "$dir/requirements.txt" ]; then
        return 0
    fi
    return 1
}

# Detect and display project type (only for project directories)
detect_project_type() {
    local dir="$1"
    if [ -f "$dir/package.json" ]; then
        # Check if it's React, Next.js, Vue, etc.
        if grep -q '"next"' "$dir/package.json" 2>/dev/null; then
            echo "⚡Next.js"
        elif grep -q '"react"' "$dir/package.json" 2>/dev/null; then
            echo "⚛ React"
        elif grep -q '"vue"' "$dir/package.json" 2>/dev/null; then
            echo "💚Vue"
        else
            echo "📦Node"
        fi
    elif [ -f "$dir/requirements.txt" ] || [ -f "$dir/setup.py" ] || [ -f "$dir/pyproject.toml" ]; then
        echo "🐍Python"
    elif [ -f "$dir/Cargo.toml" ]; then
        echo "🦀Rust"
    elif [ -f "$dir/go.mod" ]; then
        echo "🐹Go"
    elif [ -f "$dir/Gemfile" ]; then
        echo "💎Ruby"
    elif [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ]; then
        echo "☕Java"
    elif [ -f "$dir/composer.json" ]; then
        echo "🐘PHP"
    fi
}

# Only run expensive operations in project directories
if is_project_dir "$cwd"; then
    project_type=$(detect_project_type "$cwd")
    if [ -n "$project_type" ]; then
        status_parts+=("$project_type")
    fi

    # Add git branch, dirty indicator, ahead/behind (only in actual git repos)
    if [ -d "$cwd/.git" ]; then
        branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [ -n "$branch" ]; then
            git_status=""

            # Check if there are uncommitted changes
            if ! git -C "$cwd" diff --quiet 2>/dev/null || ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
                git_status="$(printf "\033[33m%s\033[0m ●" "$branch")"
            else
                git_status="$(printf "\033[36m%s\033[0m" "$branch")"
            fi

            # Check ahead/behind remote (with timeout)
            upstream=$(timeout 1 git -C "$cwd" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
            if [ -n "$upstream" ]; then
                ahead=$(timeout 1 git -C "$cwd" rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
                behind=$(timeout 1 git -C "$cwd" rev-list --count HEAD..@{u} 2>/dev/null || echo "0")

                ahead_behind=""
                if [ "$ahead" -gt 0 ] 2>/dev/null; then
                    ahead_behind+="↑$ahead"
                fi
                if [ "$behind" -gt 0 ] 2>/dev/null; then
                    ahead_behind+="↓$behind"
                fi

                if [ -n "$ahead_behind" ]; then
                    git_status+=" $ahead_behind"
                fi
            fi

            status_parts+=("$git_status")

            # Simplified git info - just show untracked/staged/modified counts
            untracked_count=$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
            staged_count=$(git -C "$cwd" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
            modified_count=$(git -C "$cwd" diff --name-only 2>/dev/null | wc -l | tr -d ' ')

            git_changes=""
            if [ "$untracked_count" -gt 0 ] 2>/dev/null; then
                git_changes+="$(printf "\033[91m+%d\033[0m " "$untracked_count")"
            fi
            if [ "$staged_count" -gt 0 ] 2>/dev/null; then
                git_changes+="$(printf "\033[32m✓%d\033[0m " "$staged_count")"
            fi
            if [ "$modified_count" -gt 0 ] 2>/dev/null; then
                git_changes+="$(printf "\033[33m~%d\033[0m" "$modified_count")"
            fi

            if [ -n "$git_changes" ]; then
                status_parts+=("$git_changes")
            fi
        fi
    fi
fi

# Add active plugins count (fast - just reading local JSON)
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ]; then
    plugin_count=$(jq '[.enabledPlugins // {} | to_entries[] | select(.value == true)] | length' "$settings_file" 2>/dev/null)
    if [ -n "$plugin_count" ] && [ "$plugin_count" -gt 0 ]; then
        status_parts+=("$(printf "\033[35m%d plugins\033[0m" "$plugin_count")")
    fi
fi


# Add hooks count (fast - local JSON)
if [ -f "$settings_file" ]; then
    hooks_count=$(jq '[.hooks // {} | to_entries[] | .value[]] | length' "$settings_file" 2>/dev/null)
    if [ -n "$hooks_count" ] && [ "$hooks_count" -gt 0 ]; then
        status_parts+=("$(printf "\033[33m%d hooks\033[0m" "$hooks_count")")
    fi
fi

# Add context window progress bar and cost estimate
if [ "$usage" != "null" ] && [ -n "$usage" ]; then
    input_tokens=$(echo "$usage" | jq -r '.input_tokens // 0')
    output_tokens=$(echo "$usage" | jq -r '.output_tokens // 0')
    cache_creation=$(echo "$usage" | jq -r '.cache_creation_input_tokens // 0')
    cache_read=$(echo "$usage" | jq -r '.cache_read_input_tokens // 0')

    # Validate numbers
    input_tokens=${input_tokens:-0}
    output_tokens=${output_tokens:-0}
    cache_creation=${cache_creation:-0}
    cache_read=${cache_read:-0}

    current=$((input_tokens + cache_creation + cache_read))
    size=$(echo "$input" | jq '.context_window.context_window_size // 200000')
    size=${size:-200000}

    if [ "$current" -gt 0 ] 2>/dev/null && [ "$size" -gt 0 ] 2>/dev/null; then
        pct=$((current * 100 / size))

        # Create visual progress bar (10 characters wide for speed)
        bar_width=10
        filled=$((pct * bar_width / 100))
        empty=$((bar_width - filled))

        bar=""
        for ((i=0; i<filled; i++)); do
            bar+="█"
        done
        for ((i=0; i<empty; i++)); do
            bar+="░"
        done

        # Color based on usage level
        if [ $pct -ge 80 ]; then
            color_bar=$(printf "\033[31m%s\033[0m" "$bar")
        elif [ $pct -ge 60 ]; then
            color_bar=$(printf "\033[33m%s\033[0m" "$bar")
        else
            color_bar=$(printf "\033[32m%s\033[0m" "$bar")
        fi

        # Format context window size as human-readable (e.g. 200000 → 200k)
        if [ "$size" -ge 1000000 ] 2>/dev/null; then
            size_label=$(awk -v s="$size" 'BEGIN { printf "%.0fm", s/1000000 }')
        elif [ "$size" -ge 1000 ] 2>/dev/null; then
            size_label=$(awk -v s="$size" 'BEGIN { printf "%.0fk", s/1000 }')
        else
            size_label="$size"
        fi

        status_parts+=("[$color_bar ${pct}% / ${size_label}]")

        # Calculate cost estimate
        case "$model_id" in
            *"claude-opus-4"*)
                input_price=15.00
                output_price=75.00
                cache_write_price=18.75
                cache_read_price=1.50
                ;;
            *"claude-sonnet-4"*|*"claude-3-7-sonnet"*|*"claude-3-5-sonnet"*)
                input_price=3.00
                output_price=15.00
                cache_write_price=3.75
                cache_read_price=0.30
                ;;
            *"claude-3-5-haiku"*)
                input_price=0.80
                output_price=4.00
                cache_write_price=1.00
                cache_read_price=0.08
                ;;
            *)
                input_price=3.00
                output_price=15.00
                cache_write_price=3.75
                cache_read_price=0.30
                ;;
        esac

        cost=$(awk -v it="$input_tokens" -v ot="$output_tokens" -v cc="$cache_creation" -v cr="$cache_read" \
                   -v ip="$input_price" -v op="$output_price" -v cp="$cache_write_price" -v rp="$cache_read_price" \
                   'BEGIN {
                       total = (it * ip + ot * op + cc * cp + cr * rp) / 1000000
                       if (total >= 0.01) printf "%.2f", total
                       else if (total >= 0.001) printf "%.3f", total
                       else printf "%.4f", total
                   }')

        if [ -n "$cost" ] && [ "$cost" != "0.0000" ]; then
            status_parts+=("$(printf "\033[32m\$%s\033[0m" "$cost")")
        fi
    fi
fi

# Join all parts with spaces and output
printf "%s\n" "${status_parts[*]}"
