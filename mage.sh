#!/bin/bash

# Configuration
API_URL="$MAGE_API_URL"
MODEL="$MAGE_MODEL"
MAX_TOKENS="$MAGE_MAX_TOKENS"
TEMPERATURE="$MAGE_TEMPERATURE"
HISTORY_FILE="$MAGE_HISTORY_FILE"

# ANSI Color Codes
GREEN="\033[0;32m"
PURPLE="\033[0;35m"
RED="\033[0;31m"
NO_COLOR="\033[0m"

# Function to escape strings for JSON
escape_json() {
    jq -aRs <<<"$1"
}

# Initialize conversation history array with the system prompt
SYSTEM_PROMPT='{"role": "system", "content": "You are an advanced AI assistant. You have a wide range of knowledge on many topics. Make responses formatted in markdown, using various formatting techniques, such as headers, bold and italicized text, code blocks, lists, blockquotes, links etc where appropriate."}'
declare -a CONVERSATION_HISTORY=()

# Initialize HISTORY_FILE if it doesn't exist
if [ ! -f "$HISTORY_FILE" ]; then
    echo "$SYSTEM_PROMPT" > "$HISTORY_FILE"
fi

# Load history from file
load_history() {
    if [ -f "$HISTORY_FILE" ]; then
        while IFS= read -r line; do
            if echo "$line" | jq empty; then
                CONVERSATION_HISTORY+=("$line")
            else
                echo -e "${RED}Warning: Skipping invalid JSON line in history.${NO_COLOR}"
            fi
        done < "$HISTORY_FILE"
    fi
}

# Save history to file
save_history() {
    printf "%s\n" "${CONVERSATION_HISTORY[@]}" > "$HISTORY_FILE"
}

# Spinner animation
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

# Send a chat request with history
send_chat_request() {
    local user_input="$1"
    local user_message
    user_message=$(jq -nc --arg role "user" --arg content "$user_input" '{"role": $role, "content": $content}')
    CONVERSATION_HISTORY+=("$user_message")

    # Create a temporary file for the response
    local temp_response_file
    temp_response_file=$(mktemp)

    # Construct messages array as a single JSON array
    local messages_json
    messages_json=$(printf "%s\n" "${CONVERSATION_HISTORY[@]}" | jq -s '.')

    # Debug: Print messages_json
    echo "Constructed messages JSON:"
    echo "$messages_json"

    # Validate messages_json
    if ! echo "$messages_json" | jq empty; then
        echo -e "${RED}Error: Constructed messages JSON is invalid.${NO_COLOR}"
        rm "$temp_response_file"
        return 1
    fi

    # Construct the entire JSON payload using jq directly
    local json_payload
    json_payload=$(jq -n \
        --arg model "$MODEL" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson temperature "$TEMPERATURE" \
        --argjson messages "$messages_json" \
        '{
            model: $model,
            messages: $messages,
            max_tokens: $max_tokens,
            temperature: $temperature
        }')

    # Validate json_payload
    if ! echo "$json_payload" | jq empty; then
        echo -e "${RED}Error: Constructed JSON payload is invalid.${NO_COLOR}"
        rm "$temp_response_file"
        return 1
    fi

    # Debug: Print json_payload
    echo "Constructed JSON payload:"
    echo "$json_payload"

    # Run curl in the background, directing output to the temporary file
    curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "$json_payload" > "$temp_response_file" &
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
        
        # Use glow to render the Markdown content
        glow "$temp_md_file"
        rm "$temp_md_file" # Clean up the temporary Markdown file

        local assistant_message
        assistant_message=$(jq -nc --arg role "assistant" --arg content "$assistant_response" '{"role": $role, "content": $content}')
        CONVERSATION_HISTORY+=("$assistant_message")
        save_history
    fi
}

# Main interaction loop
load_history
echo "Welcome to the Mage CLI. Type 'exit' or 'quit' to end."
while true; do
    echo -ne "${GREEN}>${NO_COLOR} "
    read user_input

    if [[ "$user_input" =~ ^(exit|quit)$ ]]; then
        echo "Goodbye!"
        break
    else
        send_chat_request "$user_input"
    fi
done
