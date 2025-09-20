#!/usr/bin/env bash
# Mastodon Docker Cleanup Script
# Inspired by: https://codeberg.org/Fedimins/mastodon-maintenance-tasks
# Licensed under CC BY-SA 4.0

# Default configuration
DAYS=30                    # Age threshold for cleanups
CONTAINER="mastodon"       # Docker container name
LOG_PATH="/var/log/mastodon"  # Log directory on host
PID_FILE="/tmp/mastodon-cleanup.pid"  # PID file for preventing concurrent runs
DEPENDENCIES=("docker" "awk" "date")  # Required commands

# Flags for cleanup tasks
LOGGING_ENABLED=false
ACCOUNTS_PRUNE_ENABLED=false
STATUSES_REMOVE_ENABLED=false
MEDIA_REMOVE_ENABLED=false
MEDIA_REMOVE_ORPHAN_ENABLED=false
PREVIEW_CARDS_REMOVE_ENABLED=false
CACHE_CLEAR_ENABLED=false
MEDIA_USAGE_ENABLED=false

# Function: help
# Purpose: Display usage instructions
function help() {
  echo "Mastodon Docker Cleanup Script"
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --days <n>           Set age threshold for cleanups (default: $DAYS)"
  echo "  --logging            Enable logging to $LOG_PATH"
  echo "  --cleanup            Run all safe cleanup tasks (media, orphans, previews, statuses, cache)"
  echo "  --accountsprune      Prune inactive remote accounts (use with caution)"
  echo "  --statusesremove     Remove orphaned statuses"
  echo "  --mediaremove        Remove old cached media and profiles"
  echo "  --mediaremoveorphan  Remove orphaned media files"
  echo "  --previewcardsremove Remove old preview cards"
  echo "  --cacheclear         Clear Redis cache"
  echo "  --mediausage         Show media disk usage"
  echo "  --help, -h           Display this help"
  echo "Example: $0 --cleanup --days 7 --logging"
}

# Function: check_command
# Purpose: Verify if a command is available
function check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo "Error: $1 is not installed."
    exit 1
  fi
}

# Function: check_dependency
# Purpose: Check all required dependencies
function check_dependency() {
  for cmd in "${DEPENDENCIES[@]}"; do


    check_command "$cmd"



  done
}

# Function: check_pid

# Purpose: Prevent concurrent script runs
function check_pid() {
  if [ -e "$PID_FILE" ]; then



    STORED_PID=$(cat "$PID_FILE")




    if ps -p "$STORED_PID" >/dev/null; then



      echo "Error: Script is already running (PID: $STORED_PID)."



      exit 1
    else
      echo "No running process for PID: $STORED_PID. Deleting $PID_FILE."




      rm -f "$PID_FILE"



    fi

  fi

}

# Function: create_pid

# Purpose: Create PID file for this run

function create_pid() {
  if ! echo "$$" >"$PID_FILE"; then





    echo "Error: Could not create PID file."
    exit 1
  fi
}

# Function: logging
# Purpose: Set up logging and rotate old logs
function logging() {
  if [ ! -d "$LOG_PATH" ]; then
    mkdir -p "$LOG_PATH"
  fi
  LOG_DATE=$(date +"%Y-%m-%d")
  exec &> >(tee -a "$LOG_PATH/mastodon-cleanup-$LOG_DATE.log")
  find "$LOG_PATH" -name "mastodon-cleanup-*.log" -type f -mtime +30 -exec rm {} \;
}

# Function: time_start
# Purpose: Record script start time
function time_start() {
  START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
  echo "Script started at $START_TIME"
}

# Function: time_end
# Purpose: Record end time and calculate duration
function time_end() {
  END_TIME=$(date +"%Y-%m-%d %H:%M:%S")
  SECONDS=$(( $(date -d "$END_TIME" +%s) - $(date -d "$START_TIME" +%s) ))
  HOURS=$((SECONDS / 3600))
  MINUTES=$(((SECONDS % 3600) / 60))
  SECONDS=$((SECONDS % 60))
  echo "Script finished at $END_TIME (Duration: $HOURS hours $MINUTES minutes $SECONDS seconds)"
}

# Function: run_tootctl
# Purpose: Execute tootctl command in Docker container
function run_tootctl() {
  docker exec "$CONTAINER" bundle exec tootctl "$@"
}

# Function: accounts_prune
# Purpose: Prune inactive remote accounts
function accounts_prune() {
  echo "Pruning inactive remote accounts..."
  run_tootctl accounts prune
}

# Function: statuses_remove
# Purpose: Remove orphaned statuses
function statuses_remove() {
  echo "Removing orphaned statuses..."
  run_tootctl statuses remove --days "$DAYS"
}

# Function: media_remove
# Purpose: Remove old cached media and profiles
function media_remove() {
  echo "Removing old cached media and profiles..."
  run_tootctl media remove --days "$DAYS" && \
  run_tootctl media remove --prune-profiles --days "$DAYS"
}

# Function: media_remove_orphans
# Purpose: Remove orphaned media files
function media_remove_orphans() {
  echo "Removing orphaned media files..."
  run_tootctl media remove-orphans
}

# Function: preview_cards_remove
# Purpose: Remove old preview cards
function preview_cards_remove() {
  echo "Removing old preview cards..."
  run_tootctl preview_cards remove --days "$DAYS"
}

# Function: cache_clear
# Purpose: Clear Redis cache
function cache_clear() {
  echo "Clearing Redis cache..."
  run_tootctl cache clear
}

# Function: media_usage
# Purpose: Show media disk usage
function media_usage() {
  echo "Calculating media disk usage..."
  run_tootctl media usage
  echo "Disk usage in /live/public/system:"
  docker exec "$CONTAINER" df -h /live/public/system
}

# Function: script_cleanup
# Purpose: Clean up PID file on exit
function script_cleanup() {
  [ -f "$PID_FILE" ] && rm "$PID_FILE"
}

# Check for no arguments
if [ $# -eq 0 ]; then
  help
  exit 0
fi

# Parse command-line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --days)
      DAYS="$2"
      shift 2
      ;;
    --logging)
      LOGGING_ENABLED=true
      shift
      ;;
    --cleanup)
      STATUSES_REMOVE_ENABLED=true
      MEDIA_REMOVE_ENABLED=true
      MEDIA_REMOVE_ORPHAN_ENABLED=true
      PREVIEW_CARDS_REMOVE_ENABLED=true
      CACHE_CLEAR_ENABLED=true
      shift
      ;;
    --accountsprune)
      ACCOUNTS_PRUNE_ENABLED=true
      shift
      ;;
    --statusesremove)
      STATUSES_REMOVE_ENABLED=true
      shift
      ;;
    --mediaremove)
      MEDIA_REMOVE_ENABLED=true
      shift
      ;;
    --mediaremoveorphan)
      MEDIA_REMOVE_ORPHAN_ENABLED=true
      shift
      ;;
    --previewcardsremove)

      PREVIEW_CARDS_REMOVE_ENABLED=true
      shift
      ;;
    --cacheclear)

      CACHE_CLEAR_ENABLED=true
      shift
      ;;
    --mediausage)

      MEDIA_USAGE_ENABLED=true
      shift
      ;;
    -h|--help)
      help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"



      help
      exit 1
      ;;
  esac

done

# Validate dependencies and container
check_dependency
if ! docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER}$"; then


  echo "Error: Container '$CONTAINER' is not running."



  exit 1
fi


# Prevent concurrent runs
check_pid
create_pid

# Enable logging if specified
[ "$LOGGING_ENABLED" = true ] && logging





# Track execution time
time_start

# Execute enabled cleanup tasks
[ "$ACCOUNTS_PRUNE_ENABLED" = true ] && accounts_prune








[ "$STATUSES_REMOVE_ENABLED" = true ] && statuses_remove













[ "$MEDIA_REMOVE_ENABLED" = true ] && media_remove













[ "$MEDIA_REMOVE_ORPHAN_ENABLED" = true ] && media_remove_orphans












[ "$PREVIEW_CARDS_REMOVE_ENABLED" = true ] && preview_cards_remove

















[ "$CACHE_CLEAR_ENABLED" = true ] && cache_clear




















[ "$MEDIA_USAGE_ENABLED" = true ] && media_usage

































# Finalize
time_end
trap 'script_cleanup' EXIT





















































