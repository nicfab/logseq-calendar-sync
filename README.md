# Logseq Calendar Sync

Smart calendar and reminders synchronization script for Logseq journals using icalpal on macOS.

## Features

- 📅 **Calendar Integration**: Syncs events from macOS Calendar app
- ⏰ **Reminders Support**: Syncs reminders from macOS Reminders app
- 🎯 **Calendar Filtering**: Whitelist specific calendars to include/exclude
- 🔄 **Smart Parsing**: Intelligent parsing of scheduled reminders vs regular events
- 📝 **Logseq Integration**: Automatic journal entry creation with proper formatting
- 🗂️ **Backup Protection**: Automatic backup of existing content before updates
- 📊 **Comprehensive Logging**: Detailed logging with DEBUG mode support
- 🔔 **Native Notifications**: macOS notifications on sync completion
- ⚡ **Incremental Updates**: Updates existing agenda sections without losing other content

## Requirements

- **macOS** (tested on macOS 13+)
- **[icalpal](https://github.com/icalpal/icalpal)** Ruby gem (version 3.9.1+ required)
- **Logseq** with iCloud sync enabled
- **Zsh shell** (default on modern macOS)
- **Ruby** with gem support

## Installation

### 1. Install icalpal

**⚠️ Important Update (August 11, 2025):** This script has been updated for icalpal 3.9.1 compatibility. The `reminders` command has been replaced with `tasksDueBefore`. Please ensure you have the latest version.

```bash
gem install icalpal
```

Verify installation:

```bash
icalpal --version
# Should show 3.9.1 or later
```

### 2. Download the script

```bash
# Download directly
curl -O https://raw.githubusercontent.com/nicfab/logseq-calendar-sync/main/logseq-calendar-sync.sh

# Make executable
chmod +x logseq-calendar-sync.sh

# Move to a suitable location (optional)
mv logseq-calendar-sync.sh ~/Scripts/
```

### 3. Configure icalpal

Set up icalpal for 24-hour time format:

```bash
# Create icalpal config directory
mkdir -p ~/.icalpal

# Configure for 24-hour format
echo "time_format: 24" > ~/.icalpal/config.yml
```

## Configuration

Edit the configuration variables at the top of the script:

```bash
# Logseq vault path (default for iCloud sync)
VAULT="$HOME/Library/Mobile Documents/iCloud~com~logseq~logseq/Documents/journals"

# icalpal installation path (adjust based on your Ruby setup)
ICALPAL="$HOME/.gem/ruby/3.4.0/bin/icalpal"

# Calendars to include (case sensitive)
ALLOWED_CALENDARS=("Calendar" "Personal" "Work" "Family")

# Enable debug logging
DEBUG=false

# Log file location
LOG_FILE="$HOME/Scripts/logseq_calendar.log"
```

### Finding Your icalpal Path

If you're unsure about the icalpal path:

```bash
which icalpal
# or
gem environment | grep "EXECUTABLE DIRECTORY"
```

### Calendar Names

To find your exact calendar names:

```bash
icalpal calendars
```

To list reminders/tasks:

```bash
# New command in icalpal 3.9.1+
icalpal tasksDueBefore --days 1
```

Use the exact names (case sensitive) in the `ALLOWED_CALENDARS` array.

## Usage

### Manual Execution

```bash
./logseq-calendar-sync.sh
```

### With Debug Mode

```bash
DEBUG=true ./logseq-calendar-sync.sh
```

### Automated Scheduling

Set up a cron job for automatic syncing:

```bash
# Edit crontab
crontab -e

# Add entry for sync every 30 minutes during work hours
*/30 8-18 * * 1-5 /path/to/logseq-calendar-sync.sh

# Or sync every hour
0 * * * * /path/to/logseq-calendar-sync.sh
```

### LaunchAgent (macOS Alternative)

Create a LaunchAgent for better macOS integration:

```bash
# Create plist file
cat > ~/Library/LaunchAgents/com.user.logseq-calendar-sync.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.logseq-calendar-sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/logseq-calendar-sync.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Load the agent
launchctl load ~/Library/LaunchAgents/com.user.logseq-calendar-sync.plist
```

## Output Format

The script creates a structured agenda in your daily Logseq journal:

```markdown
# Today's Agenda

## Events

- **09:00** - Team Meeting _(Work)_
- **all day event** - Conference _(Work)_
- **14:30** - Doctor Appointment _(Personal)_

## Reminders

- **10:00** - Call client _(Work Tasks)_
- **reminder** - Buy groceries _(Personal)_
- 📅 Upcoming: 5 reminders in the next 7 days

---

_Last sync: 14:32:15_
```

## How It Works

1. **Data Retrieval**: Uses icalpal to fetch today's events and reminders
2. **Intelligent Filtering**:
   - Excludes calendars not in the whitelist
   - Separates regular events from scheduled reminders
   - Filters out completed and recurring reminders
3. **Smart Parsing**:
   - Handles both timed and all-day events
   - Cross-references reminder data for accurate list names
   - Counts upcoming reminders for the next 7 days
4. **Journal Integration**:
   - Creates or updates the "Today's Agenda" section
   - Preserves existing journal content
   - Creates automatic backups before modifications
5. **Logging & Notifications**: Comprehensive logging with macOS notifications

## Troubleshooting

### Version Compatibility

**icalpal 3.9.1+ required**

- The script uses `tasksDueBefore` command introduced in icalpal 3.9.1
- If using older versions, upgrade with: `gem update icalpal`

### Common Issues

**icalpal not found**

```bash
# Check if icalpal is installed
gem list icalpal

# Install if missing
gem install icalpal
```

**Permission denied**

```bash
# Make script executable
chmod +x logseq-calendar-sync.sh
```

**No events/reminders showing**

- Check calendar permissions in System Preferences → Security & Privacy → Privacy → Calendars
- Verify calendar names in `ALLOWED_CALENDARS` match exactly (case sensitive)
- Run with `DEBUG=true` to see detailed processing

**iCloud sync issues**

- Ensure Logseq iCloud sync is enabled and working
- Check the `VAULT` path points to your actual Logseq directory

### Debug Mode

Enable debug logging to troubleshoot issues:

```bash
DEBUG=true ./logseq-calendar-sync.sh
```

Check the log file for detailed information:

```bash
tail -f ~/Scripts/logseq_calendar.log
```

## Changelog

### v1.1 - August 11, 2025

- **BREAKING**: Updated for icalpal 3.9.1 compatibility
- Replaced `reminders` command with `tasksDueBefore` (icalpal 3.9.1+ requirement)
- Updated all reminder-related functions to use new API
- Added version compatibility checks in documentation

### v1.0 - August 11, 2025

- Initial release
- Full calendar and reminders synchronization
- Smart filtering and parsing capabilities
- Automatic backup system

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License

Copyright (c) 2025 Nicola Fabiano

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Acknowledgments

- [icalpal](https://github.com/icalpal/icalpal) - Ruby gem for macOS Calendar and Reminders access
- [Logseq](https://logseq.com/) - Privacy-first, open-source knowledge base
- The open-source community for inspiration and best practices
