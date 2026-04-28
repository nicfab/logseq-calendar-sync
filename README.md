# Logseq Calendar Sync

Smart calendar and reminders synchronization script for Logseq journals using [icalPal](https://github.com/ajrosen/icalPal) on macOS.

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
- 🔍 **Auto-detect icalPal**: Works with Homebrew tap, gem user-install, or any custom path

## Requirements

- **macOS** (tested on macOS 13+)
- **[icalPal](https://github.com/ajrosen/icalPal)** version **3.9.1+** (4.2.0 recommended via Homebrew tap)
- **Logseq** with iCloud sync enabled
- **Zsh shell** (default on modern macOS)
- **Ruby** with gem support (only if installing icalPal via `gem install`)

## Installation

### 1. Install icalPal

**Recommended — Homebrew tap (most reliable, includes 4.2.0):**

```bash
brew install ajrosen/tap/icalPal
```

This installs `icalPal` (and the lowercase alias `icalpal`) into `/opt/homebrew/bin/`, with all Ruby dependencies handled by Homebrew. No need to manage `GEM_HOME` or PATH.

**Alternative — RubyGems (note the case):**

```bash
gem install icalPal
```

> ⚠️ **Note**: the gem name is `icalPal` (capital P). The lowercase form `icalpal` will fail with `ERROR: Could not find a valid gem 'icalpal'`.
>
> ⚠️ icalPal **4.2.0** has a known build issue when installed via plain `gem install` against a Homebrew-managed Ruby (read-only Cellar). If you hit `Gem::FilePermissionError` or `TypeError: no implicit conversion of Gem::FilePermissionError into String`, use the Homebrew tap above instead. See upstream [issue #54](https://github.com/ajrosen/icalPal/issues/54) for details. Versions 3.9.1 through 4.1.1 install cleanly via `gem install`.

Verify installation:

```bash
icalPal --version
# Should report 3.9.1 or later (4.2.0 recommended)
```

### 2. Download the script

```bash
# Download directly
curl -O https://raw.githubusercontent.com/nicfab/logseq-calendar-sync/main/logseq-calendar-sync.sh

# Make executable
chmod +x logseq-calendar-sync.sh

# Move to a location of your choice (optional)
mv logseq-calendar-sync.sh ~/bin/
```

### 3. Configure icalPal (optional but recommended)

icalPal reads default options from `~/.icalpal` — note: this is a **single file**, not a directory or a YAML config. Each line is a CLI flag. To enforce 24-hour times and a stable date format, create the file like this:

```bash
cat > ~/.icalpal <<'EOF'
--tf %H:%M
--df %Y-%m-%d
--sort start_date
EOF
```

> See [`icalPal --help`](https://github.com/ajrosen/icalPal#config-files) for all available flags.

## Configuration

The script auto-detects `icalPal` from your `PATH` and falls back to common gem user-install locations. In most cases you don't need to set anything. If you want to pin a specific binary, edit the script or export the variable before running:

```bash
export ICALPAL=/opt/homebrew/bin/icalPal
```

Other variables you may want to customize at the top of the script:

```bash
# Logseq vault path (default for iCloud sync)
VAULT="$HOME/Library/Mobile Documents/iCloud~com~logseq~logseq/Documents/journals"

# Calendars to include (case sensitive)
ALLOWED_CALENDARS=("Calendar" "Personal" "Work" "Family")

# Enable debug logging
DEBUG=false

# Log file (default: $HOME/.local/share/logseq-calendar-sync/sync.log)
LOG_FILE="$HOME/.local/share/logseq-calendar-sync/sync.log"
```

### Finding Your icalPal Path

If the auto-detection picks the wrong binary, find available installations with:

```bash
which icalPal
which icalpal
gem environment | grep "EXECUTABLE DIRECTORY"
```

### Calendar Names

To find your exact calendar names:

```bash
icalPal calendars
```

To list reminders/tasks:

```bash
# tasksDueBefore is the icalPal 3.9.1+ command (replaces the older 'reminders')
icalPal tasksDueBefore --days 1
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

1. **Data Retrieval**: Uses icalPal to fetch today's events and reminders
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

**icalPal 3.9.1+ required**

- The script uses the `tasksDueBefore` command introduced in icalPal 3.9.1.
- 4.2.0 is recommended via the Homebrew tap (`brew install ajrosen/tap/icalPal`).

### Common Issues

**`gem install icalPal -v 4.2.0` fails with `Gem::FilePermissionError` or `TypeError`**

This is an upstream bug specific to plain `gem install` against a Homebrew-managed Ruby — see [ajrosen/icalPal#54](https://github.com/ajrosen/icalPal/issues/54). Use the Homebrew tap instead:

```bash
brew install ajrosen/tap/icalPal
```

**icalPal not found**

The script auto-detects `icalPal` and `icalpal` in `PATH` and falls back to common gem user-install locations. If it still fails, install via Homebrew or set the `ICALPAL` variable:

```bash
export ICALPAL=/path/to/icalPal
./logseq-calendar-sync.sh
```

**Permission denied**

```bash
chmod +x logseq-calendar-sync.sh
```

**No events/reminders showing**

- Check calendar permissions in System Settings → Privacy & Security → Calendars (and Reminders)
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
tail -f ~/.local/share/logseq-calendar-sync/sync.log
```

## Changelog

### v1.2 - April 28, 2026

- **Added**: auto-detect of `icalPal`/`icalpal` binary via `command -v`, with fallback to common gem user-install locations. No more hardcoded paths required for typical Homebrew or gem installations.
- **Added**: explicit Homebrew tap installation as the recommended path (`brew install ajrosen/tap/icalPal`), which avoids the upstream `gem install` build failure on Homebrew-managed Ruby.
- **Added**: troubleshooting section with reference to upstream [issue #54](https://github.com/ajrosen/icalPal/issues/54) for users hitting the 4.2.0 install error.
- **Added**: optional `ICALPAL` environment variable to override the detected binary.
- **Changed**: default `LOG_FILE` location moved to `$HOME/.local/share/logseq-calendar-sync/sync.log` (XDG-style state directory) instead of the previous `$HOME/Scripts/`.
- **Fixed**: documentation of the icalPal config — `~/.icalpal` is a single file with one CLI flag per line, not a directory containing a YAML file.
- **Fixed**: corrected the `gem install` command to use the proper case (`icalPal`, not `icalpal`).
- **Fixed**: corrected the upstream icalPal repository link (was pointing to a non-existent repo).
- **Fixed**: minor whitespace and consistency cleanup.

### v1.1 - August 11, 2025

- **BREAKING**: Updated for icalPal 3.9.1 compatibility
- Replaced `reminders` command with `tasksDueBefore` (icalPal 3.9.1+ requirement)
- Updated all reminder-related functions to use new API
- Added version compatibility checks in documentation

### v1.0 - August 11, 2025

- Initial release
- Full calendar and reminders synchronization
- Smart filtering and parsing capabilities
- Automatic backup system

**Project developed with the support of Claude by [Anthropic](https://github.com/anthropics), under careful human oversight provided by me.**

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

- [icalPal](https://github.com/ajrosen/icalPal) - Ruby gem by Andy Rosen for macOS Calendar and Reminders access
- [Logseq](https://logseq.com/) - Privacy-first, open-source knowledge base
- The open-source community for inspiration and best practices
