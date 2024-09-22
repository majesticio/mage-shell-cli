#!/bin/bash

# Configuration
API_URL="http://10.200.200.1:11434/v1/chat/completions"
MODEL="mixtral"
MAX_TOKENS=10000
TEMPERATURE=0.7
HISTORY_FILE="$HOME/.chat_history"

# ANSI Color Codes
GREEN="\033[0;32m"
PURPLE="\033[0;35m"
NO_COLOR="\033[0m"

# Function to escape strings for JSON
escape_json() {
    jq -aRs <<<"$1"
}

# Initialize conversation history array with the system prompt
SYSTEM_PROMPT='{"role": "system", "content": "You are an advanced AI assistant. You have a wide range of knowledge on many topics. Make responses formatted in markdown, using various formatting techniques, such as headers, bold and italicized text, code blocks, lists, blockquotes, links etc where appropriate."}'
declare -a CONVERSATION_HISTORY=("$SYSTEM_PROMPT")

# Load history from file
load_history() {
    if [ -f "$HISTORY_FILE" ]; then
        mapfile -t CONVERSATION_HISTORY < "$HISTORY_FILE"
    fi
}

# Save history to file
save_history() {
    printf "%s\n" "${CONVERSATION_HISTORY[@]}" > "$HISTORY_FILE"
}

# Spinner animation
# Improved Spinner Function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    echo -n " "
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\b%c" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\b"
}

# Adjusted send_chat_request to Use Background Curl and Spinner
# Send a chat request with history
send_chat_request() {
    local user_input="$1"
    local user_message=$(jq -nc --arg role "user" --arg content "$user_input" '{$role, $content}')
    CONVERSATION_HISTORY+=("$user_message")

    # Create a temporary file for the response
    local temp_response_file=$(mktemp)

    local json_payload=$(jq -nc \
        --arg model "$MODEL" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson temperature "$TEMPERATURE" \
        --argjson messages "$(printf "%s\n" "${CONVERSATION_HISTORY[@]}" | jq -s '.')" \
        '{$model, $messages, $max_tokens, $temperature}')

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
    local response=$(<"$temp_response_file")
    rm "$temp_response_file"

    # Extract HTTP status code from the response
    local http_status=$(echo "$response" | grep "HTTP_STATUS" | sed -e 's/.*HTTP_STATUS://')

    if [ "$http_status" != "200" ]; then
        echo -e "${RED}Error: HTTP status $http_status${NO_COLOR}"
        echo "$response" | jq . || echo "$response"
        return 1
    else
        local assistant_response=$(echo "$response" | sed -e 's/HTTP_STATUS.*//' | jq -r '.choices[0].message.content')
        # Save assistant's response to a temporary Markdown file
        local temp_md_file=$(mktemp)
        echo "$assistant_response" > "$temp_md_file"
        # Use glow to render the Markdown content
        glow "$temp_md_file"
        rm "$temp_md_file" # Clean up the temporary Markdown file

        local assistant_message=$(jq -nc --arg role "assistant" --arg content "$assistant_response" '{$role, $content}')
        CONVERSATION_HISTORY+=("$assistant_message")
        save_history
    fi
}

# Make sure to handle temporary storage for the curl response when running in background


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
