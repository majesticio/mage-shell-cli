#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# ===============================
# Configuration and Environment Variables
# ===============================

# Required Environment Variables
API_URL="${MAGE_API_URL}"
MODEL="${MAGE_MODEL}"

# Optional Environment Variables
API_KEY="${MAGE_API_KEY:-""}"
TEMPERATURE="${MAGE_TEMPERATURE}"
MAGE_MAX_TOKENS="${MAGE_MAX_TOKENS:-10000}"  # Default to 10000 if not set
SYSTEM_PROMPT="${MAGE_SYSTEM_PROMPT:-"You are an advanced AI assistant. You have a wide range of knowledge on many topics. Make responses formatted in markdown, using various formatting techniques, such as headers, bold and italicized text, code blocks, lists, blockquotes, links etc where appropriate."}"

HISTORY_FILE="${MAGE_HISTORY_FILE:-"$HOME/.mage_history"}"

# ===============================
# ANSI Color Codes for Output
# ===============================
GREEN="\033[0;32m"
RED="\033[0;31m"
PURPLE="\033[0;35m"
NO_COLOR="\033[0m"

# ===============================
# Function Definitions
# ===============================

# Function to display error messages and exit
error_exit() {
    echo -e "${RED}Error: $1${NO_COLOR}"
    echo "Please set the required environment variables in your shell profile (e.g., ~/.bashrc or ~/.zshrc)."
    echo "Example:"
    echo "  export $2"
    exit 1
}

# Function to check if required environment variables are set
check_required_vars() {
    if [[ -z "$API_URL" ]]; then
        error_exit "MAGE_API_URL is not set." "MAGE_API_URL=\"https://api.example.com/v1/chat/completions\""
    fi

    if [[ -z "$MODEL" ]]; then
        error_exit "MAGE_MODEL is not set." "MAGE_MODEL=\"gpt-4\""
    fi

    # MAGE_MAX_TOKENS is now optional with a default value
}

# Function to initialize the history file with default messages if it doesn't exist
initialize_history() {
    if [ ! -f "$HISTORY_FILE" ]; then
        echo '{"role": "system", "content": "'"$SYSTEM_PROMPT"'"}' > "$HISTORY_FILE"
        echo '{"role": "user", "content": "Hello Mage, follow my instructions carefully and respond briefly in the appropriate format."}' >> "$HISTORY_FILE"
        echo '{"role": "assistant", "content": "I will do my best to help with whatever you need."}' >> "$HISTORY_FILE"
    fi
}

# Function to load history from the history file
load_history() {
    if [ -f "$HISTORY_FILE" ]; then
        while IFS= read -r line; do
            if echo "$line" | jq empty 2>/dev/null; then
                CONVERSATION_HISTORY+=("$line")
            else
                echo -e "${RED}Warning: Skipping invalid JSON line in history.${NO_COLOR}"
            fi
        done < "$HISTORY_FILE"
    fi
}

# Function to save history to the history file
save_history() {
    printf "%s\n" "${CONVERSATION_HISTORY[@]}" > "$HISTORY_FILE"
}

# Function for spinner animation while waiting for background processes
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    echo -n " "
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\b%c" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\b"
}

# Function to send chat request to the API
send_chat_request() {
    local user_input="$1"

    # Create user message JSON
    local user_message
    user_message=$(jq -nc --arg role "user" --arg content "$user_input" '{"role": $role, "content": $content}')
    CONVERSATION_HISTORY+=("$user_message")

    # Create a temporary file for the response
    local temp_response_file
    temp_response_file=$(mktemp)

    # Construct messages array as a single JSON array
    local messages_json
    messages_json=$(printf "%s\n" "${CONVERSATION_HISTORY[@]}" | jq -s '.')

    # Validate messages_json
    if ! echo "$messages_json" | jq empty; then
        echo -e "${RED}Error: Constructed messages JSON is invalid.${NO_COLOR}"
        rm "$temp_response_file"
        return 1
    fi

    # Construct the entire JSON payload using jq directly
    local json_payload
    if [[ -n "$TEMPERATURE" ]]; then
        json_payload=$(jq -n \
            --arg model "$MODEL" \
            --argjson max_tokens "$MAGE_MAX_TOKENS" \
            --argjson temperature "$TEMPERATURE" \
            --argjson messages "$messages_json" \
            '{
                model: $model,
                messages: $messages,
                max_tokens: $max_tokens,
                temperature: $temperature
            }')
    else
        json_payload=$(jq -n \
            --arg model "$MODEL" \
            --argjson max_tokens "$MAGE_MAX_TOKENS" \
            --argjson messages "$messages_json" \
            '{
                model: $model,
                messages: $messages,
                max_tokens: $max_tokens
            }')
    fi

    # Validate json_payload
    if ! echo "$json_payload" | jq empty; then
        echo -e "${RED}Error: Constructed JSON payload is invalid.${NO_COLOR}"
        rm "$temp_response_file"
        return 1
    fi

    # Construct curl command
    local curl_command=(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL" \
        -H "Content-Type: application/json")

    # Add Authorization header if API_KEY is set
    if [[ -n "$API_KEY" ]]; then
        curl_command+=(-H "Authorization: Bearer $API_KEY")
    fi

    # Add data payload
    curl_command+=(-d "$json_payload")

    # Execute curl in the background, directing output to the temporary file
    "${curl_command[@]}" > "$temp_response_file" &
    local curl_pid=$!

    # Start spinner for the background curl process
    spinner "$curl_pid"

    # Wait for the curl process to finish
    wait "$curl_pid"

    # Read and remove the temporary response file
    local response
    response=$(<"$temp_response_file")
    rm "$temp_response_file"

    # Extract HTTP status code from the response
    local http_status
    http_status=$(echo "$response" | grep "HTTP_STATUS" | sed -e 's/.*HTTP_STATUS://')

    if [ "$http_status" != "200" ]; then
        echo -e "${RED}Error: HTTP status $http_status${NO_COLOR}"
        echo "$response" | jq . || echo "$response"
        return 1
    else
        local assistant_response
        assistant_response=$(echo "$response" | sed -e 's/HTTP_STATUS.*//' | jq -r '.choices[0].message.content')

        # Save assistant's response to a temporary Markdown file
        local temp_md_file
        temp_md_file=$(mktemp)
        echo "$assistant_response" > "$temp_md_file"

        # Use glow to render the Markdown content if available
        if command -v glow &> /dev/null; then
            glow "$temp_md_file"
        else
            echo -e "${PURPLE}Notice: 'glow' is not installed. Displaying response as plain text.${NO_COLOR}"
            cat "$temp_md_file"
        fi
        rm "$temp_md_file" # Clean up the temporary Markdown file

        # Create assistant message JSON
        local assistant_message
        assistant_message=$(jq -nc --arg role "assistant" --arg content "$assistant_response" '{"role": $role, "content": $content}')
        CONVERSATION_HISTORY+=("$assistant_message")
        save_history
    fi
}

# ===============================
# Main Script Execution
# ===============================

# ===============================
# Dependency Checks
# ===============================
for cmd in jq curl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed.${NO_COLOR}"
        echo "Please install it using your package manager."
        exit 1
    fi
done

# Check for glow (optional)
if ! command -v glow &> /dev/null; then
    echo -e "${PURPLE}Notice: 'glow' is not installed. Markdown responses will be displayed as plain text.${NO_COLOR}"
fi

# ===============================
# Validate Required Environment Variables
# ===============================
check_required_vars

# ===============================
# Initialize System Prompt and History
# ===============================
# The SYSTEM_PROMPT is already set via environment variable or default above

# Initialize conversation history array
declare -a CONVERSATION_HISTORY=()

# Initialize history file with system prompt and default messages if necessary
initialize_history

# Load existing history
load_history

echo "Welcome to the Mage CLI. Type 'exit' or 'quit' to end."
while true; do
    echo -ne "${GREEN}>${NO_COLOR} "
    read -r user_input

    if [[ "$user_input" =~ ^(exit|quit)$ ]]; then
        echo "Goodbye!"
        break
    elif [[ -z "$user_input" ]]; then
        continue  # Skip empty input
    else
        send_chat_request "$user_input"
    fi
done
