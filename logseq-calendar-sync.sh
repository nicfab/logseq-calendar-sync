#!/bin/zsh

# logseq-calendar-sync.sh
# Smart calendar and reminders synchronization script for Logseq journals.
# Requires icalPal 3.9.1+ (4.2.0 recommended via Homebrew).
# See: https://github.com/nicfab/logseq-calendar-sync

# 📂 Configuration - Customize these paths for your setup
# Default paths for Logseq iCloud sync - modify as needed
VAULT="$HOME/Library/Mobile Documents/iCloud~com~logseq~logseq/Documents/journals"

DATE=$(date "+%Y_%m_%d")
OUT="$VAULT/$DATE.md"
CACHE_DIR="$HOME/.logseq_calendar_cache"
BACKUP_BASE="$HOME/Library/Mobile Documents/iCloud~com~logseq~logseq/Documents/logseq/bak/journals"
BACKUP_DIR="$BACKUP_BASE/$DATE"

# icalPal command path
# Auto-detection order:
#   1. ICALPAL env variable (override)
#   2. icalPal in PATH (Homebrew tap, recommended)
#   3. icalpal in PATH (lowercase variant, also created by Homebrew)
#   4. Common gem locations (user-install)
# To pin a specific binary, export ICALPAL=/full/path/to/icalPal before running.
if [[ -z "$ICALPAL" ]]; then
    if command -v icalPal >/dev/null 2>&1; then
        ICALPAL="$(command -v icalPal)"
    elif command -v icalpal >/dev/null 2>&1; then
        ICALPAL="$(command -v icalpal)"
    else
        # Fallback: scan common gem user-install dirs (Homebrew Ruby 3.x and 4.x)
        for candidate in \
            "$HOME/.gem/ruby/4.0.0/bin/icalPal" \
            "$HOME/.gem/ruby/3.4.0/bin/icalpal" \
            "$HOME/.gem/ruby/3.3.0/bin/icalpal" \
            "/opt/homebrew/lib/ruby/gems/4.0.0/bin/icalPal"; do
            if [[ -x "$candidate" ]]; then
                ICALPAL="$candidate"
                break
            fi
        done
    fi
fi

# Debug mode + Logging
DEBUG=${DEBUG:-false}
# Default log location follows XDG-style state convention.
# Override by exporting LOG_FILE before running.
LOG_FILE="${LOG_FILE:-$HOME/.local/share/logseq-calendar-sync/sync.log}"

# ⭐ ALLOWED CALENDARS - ONLY THESE WILL BE INCLUDED
# Add your calendar names here (case sensitive)
ALLOWED_CALENDARS=("Calendar" "Personal" "Work")

# Unified logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Always write to log file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Display on screen based on level
    case "$level" in
        "ERROR")
            echo "[ERROR] $message" >&2
            ;;
        "INFO"|"SUCCESS")
            echo "[$level] $message"
            ;;
        "DEBUG")
            if [[ "$DEBUG" == "true" ]]; then
                echo "[DEBUG] $message" >&2
            fi
            ;;
    esac
}

# Function to verify if a calendar is allowed
is_calendar_allowed() {
    local calendar="$1"
    for allowed in "${ALLOWED_CALENDARS[@]}"; do
        if [[ "$calendar" == "$allowed" ]]; then
            return 0
        fi
    done
    return 1
}

# Create necessary directories
mkdir -p "$CACHE_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

log_message "INFO" "=== Smart Calendar Sync Started ==="
log_message "INFO" "Date: $(date)"
log_message "INFO" "Script: $0"
log_message "INFO" "User: $(whoami)"
log_message "INFO" "Allowed calendars: ${ALLOWED_CALENDARS[*]}"

# Verify icalPal
if [[ -z "$ICALPAL" ]] || [[ ! -x "$ICALPAL" ]]; then
    log_message "ERROR" "icalPal not found. Install with: brew install ajrosen/tap/icalPal"
    log_message "ERROR" "Or set ICALPAL=/path/to/icalPal before running."
    exit 1
fi

log_message "DEBUG" "Using icalPal: $ICALPAL"

# Version detection (informational)
ICALPAL_VERSION=$("$ICALPAL" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ -n "$ICALPAL_VERSION" ]]; then
    log_message "DEBUG" "icalPal version: $ICALPAL_VERSION"
fi

log_message "INFO" "Retrieving events and reminders for today (icalPal 3.9.1+ compatible)..."

# Get events
EVENTS=$("$ICALPAL" events --from today --to today 2>/dev/null)

# Get today's reminders (icalPal 3.9.1+ compatibility)
REMINDERS=$("$ICALPAL" tasksDueBefore --days 1 2>/dev/null)

# Fallback for events if necessary
if [[ -z "$EVENTS" ]]; then
    log_message "INFO" "No events with standard command, trying eventsToday..."
    EVENTS=$("$ICALPAL" eventsToday 2>/dev/null)
fi

log_message "DEBUG" "Events found: $(echo "$EVENTS" | grep -c "^•" 2>/dev/null || echo "0")"
log_message "DEBUG" "Reminders found: $(echo "$REMINDERS" | grep -c "^•" 2>/dev/null || echo "0")"

# Event parser (excludes reminder-type calendars AND non-allowed calendars)
parse_events() {
    local raw_events="$1"
    local formatted_events=""
    local current_event=""
    local current_calendar=""

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        log_message "DEBUG" "Processing event: $line"

        if [[ "$line" == "• "* ]]; then
            # Save previous event (all day) if from an allowed calendar
            if [[ -n "$current_event" ]] && [[ -n "$current_calendar" ]] && [[ "$current_calendar" != "Scheduled Reminders" ]]; then
                if is_calendar_allowed "$current_calendar"; then
                    formatted_events="${formatted_events}- **all day event** - $current_event _($current_calendar)_
"
                    log_message "DEBUG" "✅ All day event: $current_event ($current_calendar)"
                else
                    log_message "DEBUG" "❌ FILTERED all day event: $current_event ($current_calendar) - calendar not allowed"
                fi
            fi

            # New event
            if [[ "$line" == *"("*")" ]]; then
                current_event=$(echo "$line" | sed 's/^• *//' | sed 's/ *([^)]*)$//')
                current_calendar=$(echo "$line" | sed 's/.*(//' | sed 's/).*//')
            else
                current_event=$(echo "$line" | sed 's/^• *//')
                current_calendar="default"
            fi

            # Skip events from "Scheduled Reminders" calendar
            if [[ "$current_calendar" == "Scheduled Reminders" ]]; then
                log_message "DEBUG" "Skipped Scheduled Reminders event: $current_event"
                current_event=""
                current_calendar=""
                continue
            fi

        elif [[ "$line" == "    today at "* ]]; then
            # Time (already in 24h format with ~/.icalpal configuration)
            local time_info=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/today at //')

            # Only if not a reminder calendar AND if it's an allowed calendar
            if [[ -n "$current_event" ]] && [[ "$current_calendar" != "Scheduled Reminders" ]]; then
                if is_calendar_allowed "$current_calendar"; then
                    formatted_events="${formatted_events}- **${time_info}** - ${current_event} _($current_calendar)_
"
                    log_message "DEBUG" "✅ Timed event: ${time_info} - ${current_event} ($current_calendar)"
                else
                    log_message "DEBUG" "❌ FILTERED timed event: ${time_info} - ${current_event} ($current_calendar) - calendar not allowed"
                fi
                current_event=""
                current_calendar=""
            fi

        elif [[ "$line" == *"url:"* ]]; then
            log_message "DEBUG" "Ignored URL line: $line"
            continue
        fi
    done <<< "$raw_events"

    # Save last event (all day) if from an allowed calendar
    if [[ -n "$current_event" ]] && [[ -n "$current_calendar" ]] && [[ "$current_calendar" != "Scheduled Reminders" ]]; then
        if is_calendar_allowed "$current_calendar"; then
            formatted_events="${formatted_events}- **all day event** - $current_event _($current_calendar)_
"
            log_message "DEBUG" "✅ Last all day event: $current_event ($current_calendar)"
        else
            log_message "DEBUG" "❌ FILTERED last all day event: $current_event ($current_calendar) - calendar not allowed"
        fi
    fi

    echo "$formatted_events"
}

# Reminder parser (today only)
parse_reminders() {
    local raw_reminders="$1"
    local formatted_reminders=""
    local current_reminder=""
    local today_date=$(date '+%b %d, %Y')

    # Get CSV to verify dates (icalPal 3.9.1+ compatibility)
    local csv_reminders=$("$ICALPAL" tasksDueBefore --days 1 --output=csv 2>/dev/null)

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        log_message "DEBUG" "Processing reminder: $line"

        if [[ "$line" == "! "* ]] || [[ "$line" == "• "* ]]; then
            current_reminder=$(echo "$line" | sed 's/^[!•] *//')
            log_message "DEBUG" "New reminder: '$current_reminder'"

        elif [[ "$line" == *"due: "* ]]; then
            # Verify if it's today from CSV
            local is_today=false
            while IFS= read -r csv_line; do
                [[ "$csv_line" == "title,all_day,"* ]] && continue
                [[ -z "$csv_line" ]] && continue

                local csv_title=$(echo "$csv_line" | cut -d',' -f1 | tr -d '"')
                if [[ "$csv_title" == "$current_reminder" ]]; then
                    # Check if due date is today
                    if [[ "$csv_line" == *"\"$today_date\""* ]]; then
                        is_today=true
                        log_message "DEBUG" "Today's reminder: $current_reminder"
                    else
                        log_message "DEBUG" "NOT today's reminder: $current_reminder"
                    fi
                    break
                fi
            done <<< "$csv_reminders"

            # Only if it's today
            if [[ "$is_today" == true ]]; then
                # Extract time
                local due_info=$(echo "$line" | sed 's/.*due: *//')
                local reminder_time="reminder"

                if [[ "$due_info" == *" at "* ]]; then
                    reminder_time=$(echo "$due_info" | sed 's/.* at \([0-9:]*\).*/\1/')
                fi

                # Get list from CSV (field 13!)
                local reminder_list="Reminders"
                while IFS= read -r csv_line; do
                    if [[ "$csv_line" == *"$current_reminder"* ]]; then
                        reminder_list=$(echo "$csv_line" | cut -d',' -f13 | tr -d '"')
                        log_message "DEBUG" "Found list: '$reminder_list'"
                        break
                    fi
                done <<< "$csv_reminders"

                # Skip reminders from "Recurring" list
                if [[ "$reminder_list" == "Recurring" ]]; then
                    log_message "DEBUG" "Skipped recurring reminder: $current_reminder"
                    current_reminder=""
                    continue
                fi

                if [[ -n "$current_reminder" ]]; then
                    formatted_reminders="${formatted_reminders}- **${reminder_time}** - ${current_reminder} _(${reminder_list})_
"
                    log_message "DEBUG" "Today's reminder: ${reminder_time} - ${current_reminder} (${reminder_list})"
                fi
            fi

            current_reminder=""
        fi
    done <<< "$raw_reminders"

    echo "$formatted_reminders"
}

# Extract reminders from "Scheduled Reminders" events with correct list
extract_scheduled_reminders() {
    local raw_events="$1"
    local scheduled_reminders=""
    local current_event=""
    local current_calendar=""

    # Get CSV reminders for cross-reference of lists (icalPal 3.9.1+ compatibility)
    local csv_reminders=$("$ICALPAL" tasksDueBefore --days 1 --output=csv 2>/dev/null)

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        if [[ "$line" == "• "* ]]; then
            # Save previous scheduled reminder with correct list
            if [[ -n "$current_event" ]] && [[ "$current_calendar" == "Scheduled Reminders" ]]; then
                local correct_list=$(get_reminder_list_from_csv "$current_event" "$csv_reminders")

                log_message "DEBUG" "Checking all-day reminder '$current_event': '$correct_list'"

                # If reminder is completed or recurring, skip it
                if [[ "$correct_list" == "COMPLETED" ]]; then
                    log_message "DEBUG" "✅ SKIPPED completed all-day reminder: $current_event"
                elif [[ "$correct_list" == "Recurring" ]]; then
                    log_message "DEBUG" "✅ SKIPPED recurring all-day reminder: $current_event"
                else
                    scheduled_reminders="${scheduled_reminders}- **reminder** - $current_event _($correct_list)_
"
                    log_message "DEBUG" "✅ ADDED all-day reminder: $current_event ($correct_list)"
                fi
            fi

            # New event
            if [[ "$line" == *"("*")" ]]; then
                current_event=$(echo "$line" | sed 's/^• *//' | sed 's/ *([^)]*)$//')
                current_calendar=$(echo "$line" | sed 's/.*(//' | sed 's/).*//')
            else
                current_event=$(echo "$line" | sed 's/^• *//')
                current_calendar="default"
            fi

        elif [[ "$line" == "    today at "* ]] && [[ "$current_calendar" == "Scheduled Reminders" ]]; then
            # Time for scheduled reminder with correct list
            local time_info=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/today at //')

            if [[ -n "$current_event" ]]; then
                local correct_list=$(get_reminder_list_from_csv "$current_event" "$csv_reminders")

                # Skip reminders from "Recurring" or "COMPLETED" list
                if [[ "$correct_list" == "Recurring" ]]; then
                    log_message "DEBUG" "Skipped recurring scheduled reminder: $current_event"
                    current_event=""
                    current_calendar=""
                    continue
                elif [[ "$correct_list" == "COMPLETED" ]]; then
                    log_message "DEBUG" "Skipped completed scheduled reminder: $current_event"
                    current_event=""
                    current_calendar=""
                    continue
                fi

                scheduled_reminders="${scheduled_reminders}- **${time_info}** - ${current_event} _($correct_list)_
"
                log_message "DEBUG" "Scheduled reminder with time: ${time_info} - ${current_event} ($correct_list)"
                current_event=""
                current_calendar=""
            fi
        fi
    done <<< "$raw_events"

    # Save last scheduled reminder with correct list
    if [[ -n "$current_event" ]] && [[ "$current_calendar" == "Scheduled Reminders" ]]; then
        local correct_list=$(get_reminder_list_from_csv "$current_event" "$csv_reminders")

        # If reminder is completed or recurring, skip it
        if [[ "$correct_list" == "COMPLETED" ]]; then
            log_message "DEBUG" "Skipped last completed reminder: $current_event"
        elif [[ "$correct_list" == "Recurring" ]]; then
            log_message "DEBUG" "Skipped last recurring reminder: $current_event"
        else
            scheduled_reminders="${scheduled_reminders}- **reminder** - $current_event _($correct_list)_
"
            log_message "DEBUG" "Last scheduled reminder: $current_event ($correct_list)"
        fi
    fi

    echo "$scheduled_reminders"
}

# Helper function to find correct list from CSV reminders
get_reminder_list_from_csv() {
    local reminder_title="$1"
    local csv_reminders="$2"

    log_message "DEBUG" "Looking for list for: '$reminder_title'"

    while IFS= read -r csv_line; do
        [[ "$csv_line" == "title,all_day,"* ]] && continue
        [[ -z "$csv_line" ]] && continue

        # Check if this is our reminder
        local csv_title=$(echo "$csv_line" | cut -d',' -f1 | tr -d '"')
        if [[ "$csv_title" == "$reminder_title" ]]; then
            # list_name field is 13th in CSV (12th is color)
            local list_name=$(echo "$csv_line" | cut -d',' -f13 | tr -d '"')
            log_message "DEBUG" "Found list for '$reminder_title': '$list_name'"
            echo "$list_name"
            return 0
        fi
    done <<< "$csv_reminders"

    # If not found in CSV = it's completed = return "COMPLETED"
    log_message "DEBUG" "Reminder '$reminder_title' not found in CSV - probably completed"
    echo "COMPLETED"
}

# Count upcoming reminders (icalPal 3.9.1+ compatibility)
count_upcoming_reminders() {
    local upcoming=$("$ICALPAL" tasksDueBefore --days 8 2>/dev/null)
    echo "$upcoming" | grep -c "^•" 2>/dev/null || echo "0"
}

# Update journal file
update_journal() {
    local content="$1"

    # Backup if Agenda section exists
    if [[ -f "$OUT" ]] && grep -q "# Today's Agenda" "$OUT" 2>/dev/null; then
        local backup_file="$BACKUP_DIR/$(date -u '+%Y-%m-%dT%H_%M_%S').$(date '+%3N')Z.Desktop.md"
        cp "$OUT" "$backup_file"
        log_message "DEBUG" "Backup: $backup_file"

        # Replace section
        local agenda_line=$(grep -n "# Today's Agenda" "$OUT" | head -1 | cut -d: -f1)
        if [[ -n "$agenda_line" ]]; then
            head -n $((agenda_line - 1)) "$OUT" > "/tmp/logseq_update.md"
            echo "" >> "/tmp/logseq_update.md"
            echo "$content" >> "/tmp/logseq_update.md"
            mv "/tmp/logseq_update.md" "$OUT"
        fi
    else
        # File doesn't exist or has no agenda - create/append content
        if [[ ! -f "$OUT" ]]; then
            log_message "DEBUG" "Journal file created: $OUT"
        fi
        echo "$content" >> "$OUT"
    fi

    log_message "SUCCESS" "Journal file updated: $OUT"
}

# MAIN EXECUTION

# Build journal content
JOURNAL_CONTENT="# Today's Agenda
## Events

"

# Events section
if [[ -n "$EVENTS" ]]; then
    PARSED_EVENTS=$(parse_events "$EVENTS")
    if [[ -n "$PARSED_EVENTS" ]]; then
        JOURNAL_CONTENT="${JOURNAL_CONTENT}${PARSED_EVENTS}
"
    else
        JOURNAL_CONTENT="${JOURNAL_CONTENT}- ✅ No events for today

"
    fi
else
    JOURNAL_CONTENT="${JOURNAL_CONTENT}- ✅ No events for today

"
fi

# Reminders section
JOURNAL_CONTENT="${JOURNAL_CONTENT}## Reminders

"

# Combine normal reminders + scheduled reminders from events
COMBINED_REMINDERS=""

if [[ -n "$REMINDERS" ]]; then
    PARSED_REMINDERS=$(parse_reminders "$REMINDERS")
    if [[ -n "$PARSED_REMINDERS" ]]; then
        COMBINED_REMINDERS="$PARSED_REMINDERS"
    fi
fi

# Add scheduled reminders from events
if [[ -n "$EVENTS" ]]; then
    SCHEDULED_REMINDERS=$(extract_scheduled_reminders "$EVENTS")
    if [[ -n "$SCHEDULED_REMINDERS" ]]; then
        if [[ -n "$COMBINED_REMINDERS" ]]; then
            COMBINED_REMINDERS="${COMBINED_REMINDERS}${SCHEDULED_REMINDERS}"
        else
            COMBINED_REMINDERS="$SCHEDULED_REMINDERS"
        fi
    fi
fi

if [[ -n "$COMBINED_REMINDERS" ]]; then
    JOURNAL_CONTENT="${JOURNAL_CONTENT}${COMBINED_REMINDERS}"

    # Always add upcoming reminders info on new line
    UPCOMING_COUNT=$(count_upcoming_reminders)
    if [[ $UPCOMING_COUNT -gt 0 ]]; then
        JOURNAL_CONTENT="${JOURNAL_CONTENT}
- 📅 Upcoming: $UPCOMING_COUNT reminders in the next 7 days

"
    else
        JOURNAL_CONTENT="${JOURNAL_CONTENT}
"
    fi
else
    # No reminders today
    UPCOMING_COUNT=$(count_upcoming_reminders)
    if [[ $UPCOMING_COUNT -gt 0 ]]; then
        JOURNAL_CONTENT="${JOURNAL_CONTENT}- 🙅 No reminders for today
- 📅 Upcoming: $UPCOMING_COUNT reminders in the next 7 days

"
    else
        JOURNAL_CONTENT="${JOURNAL_CONTENT}- 🙅 No reminders for today

"
    fi
fi

# Final timestamp
JOURNAL_CONTENT="${JOURNAL_CONTENT}---
*Last sync: $(date '+%H:%M:%S')*
"

# Update journal
update_journal "$JOURNAL_CONTENT"

# Notification
if command -v osascript &> /dev/null; then
    EVENT_COUNT=$(echo "$EVENTS" | grep -c "^•" 2>/dev/null || echo "0")
    REMINDER_COUNT=$(echo "$REMINDERS" | grep -c "^•" 2>/dev/null || echo "0")
    osascript -e "display notification \"✅ $EVENT_COUNT events, $REMINDER_COUNT reminders synced\" with title \"Logseq Calendar\" sound name \"Purr\"" 2>/dev/null
fi

log_message "SUCCESS" "Synchronization completed!"
log_message "INFO" "=== End synchronization ==="
