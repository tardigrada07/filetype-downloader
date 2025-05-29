#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 \"search keyword\" filetype download_directory number_of_files api_key search_engine_id"
    echo "Example: $0 \"fairy tale\" pdf DownloadedFiles 10 YOUR_GOOGLE_API_KEY YOUR_SEARCH_ENGINE_ID"
    echo "Supported file types: pdf, docx, xlsx, pptx, txt, etc."
    echo ""
    echo "To get API key: https://developers.google.com/custom-search/v1/introduction"
    echo "To create a search engine ID: https://programmablesearchengine.google.com/controlpanel/create"
    exit 1
}

# Check if correct number of arguments provided
if [ $# -ne 6 ]; then
    usage
fi

KEYWORD="$1"
FILETYPE="$2"
DOWNLOAD_DIR="$3"
NUM_FILES="$4"
API_KEY="$5"
SEARCH_ENGINE_ID="$6"

# Validate input
if ! [[ "$NUM_FILES" =~ ^[0-9]+$ ]] || [ "$NUM_FILES" -le 0 ]; then
    echo "Error: Number of files must be a positive integer"
    exit 1
fi

if [ -z "$KEYWORD" ] || [ -z "$FILETYPE" ] || [ -z "$DOWNLOAD_DIR" ] || \
   [ -z "$API_KEY" ] || [ -z "$SEARCH_ENGINE_ID" ]; then
    echo "Error: All parameters are required"
    usage
fi

# Create download directory if it doesn't exist
if ! mkdir -p "$DOWNLOAD_DIR"; then
    echo "Error: Cannot create directory $DOWNLOAD_DIR"
    exit 1
fi

echo "Searching for $FILETYPE files with keyword \"$KEYWORD\" using Google Custom Search API..."

# Calculate how many API requests we need (Google CSE returns max 10 results per request)
# We can make multiple requests with different start indices
MAX_PER_REQUEST=10
REQUESTS_NEEDED=$(( (NUM_FILES + MAX_PER_REQUEST - 1) / MAX_PER_REQUEST ))
if [ $REQUESTS_NEEDED -gt 10 ]; then
    # Google CSE free tier limits to 100 results (10 requests of 10 results each)
    echo "Warning: Google CSE API limits free tier to 100 results. Limiting requests to 10."
    REQUESTS_NEEDED=10
fi

# Initialize an empty array for file links
declare -a ALL_LINKS

# Perform the search requests
for ((i=0; i<REQUESTS_NEEDED; i++)); do
    START_INDEX=$((i * MAX_PER_REQUEST + 1))

    # URL encode the search query
    ENCODED_QUERY=$(jq -nr --arg str "$KEYWORD" '$str|@uri')

    # Construct the API URL
    API_URL="https://customsearch.googleapis.com/customsearch/v1?cx=${SEARCH_ENGINE_ID}&fileType=$FILETYPE&key=${API_KEY}&&q=${ENCODED_QUERY}&fileType=$FILETYPE&start=${START_INDEX}"

    echo "Fetching results page $((i+1))... $API_URL"

    # Call the Google Custom Search API
    SEARCH_RESULTS=$(curl -s --header 'Accept: application/json' --compressed --connect-timeout 10 --max-time 30 "$API_URL")

    if [ $? -ne 0 ] || [ -z "$SEARCH_RESULTS" ]; then
        echo "Error: Failed to fetch search results from Google API"
        echo "Request: $API_URL"
        break
    fi

    # Check for API errors
    ERROR_MESSAGE=$(echo "$SEARCH_RESULTS" | grep -o '"error": {[^}]*}' || true)
    if [ ! -z "$ERROR_MESSAGE" ]; then
        echo "API Error: $ERROR_MESSAGE"
        echo "Please check your API key and search engine ID"
        exit 1
    fi

    # Extract file links from the JSON response
    # We'll use grep and sed to extract the link field from each item
    LINKS=$(echo "$SEARCH_RESULTS" | grep -o '"link": "[^"]*\.'$FILETYPE'[^"]*"' | \
            sed 's/"link": "//g' | sed 's/"$//g')

    # Add links to our array
    while read -r LINK; do
        if [ ! -z "$LINK" ]; then
            ALL_LINKS+=("$LINK")
        fi
    done <<< "$LINKS"

    if [ ${#ALL_LINKS[@]} -ge "$NUM_FILES" ]; then
        break
    fi

    # Small delay between API requests to be nice
    sleep 2
done

# Count found links
LINK_COUNT=${#ALL_LINKS[@]}

if [ "$LINK_COUNT" -eq 0 ]; then
    echo "No $FILETYPE files found for keyword \"$KEYWORD\""
    echo "Try using different keywords or file type"
    exit 1
fi

echo "Found $LINK_COUNT files. Starting download..."

# Download each file
COUNTER=1
SUCCESS_COUNT=0

for LINK in "${ALL_LINKS[@]}"; do
    # Generate safe filename
    FILENAME=$(basename "$LINK" | sed 's/[^a-zA-Z0-9._-]/_/g' | cut -c1-50)
    if [ -z "$FILENAME" ] || [ "$FILENAME" = "_" ]; then
        FILENAME="file_${COUNTER}.$FILETYPE"
    fi

    OUTPUT_FILE="$DOWNLOAD_DIR/${COUNTER}_${FILENAME}"

    echo "[$COUNTER/$LINK_COUNT] Downloading: $(basename "$LINK")"

    # Download with timeout and error handling
    if curl -s -L \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        --connect-timeout 10 --max-time 60 \
        --fail --output "$OUTPUT_FILE" "$LINK" 2>/dev/null; then

        # Verify file was downloaded and has content
        if [ -s "$OUTPUT_FILE" ]; then
            # Check if the file is the correct type
            FILE_TYPE=$(file -b --mime-type "$OUTPUT_FILE")
            case "$FILETYPE" in
                pdf)
                    EXPECTED_TYPE="application/pdf"
                    ;;
                docx)
                    EXPECTED_TYPE="application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                    ;;
                xlsx)
                    EXPECTED_TYPE="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    ;;
                pptx)
                    EXPECTED_TYPE="application/vnd.openxmlformats-officedocument.presentationml.presentation"
                    ;;
                *)
                    EXPECTED_TYPE=""
                    ;;
            esac

            if [ -z "$EXPECTED_TYPE" ] || [[ "$FILE_TYPE" == *"$EXPECTED_TYPE"* ]]; then
                FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
                echo "✓ Downloaded: $OUTPUT_FILE ($FILE_SIZE)"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                echo "✗ Wrong file type: $LINK (got $FILE_TYPE, expected $EXPECTED_TYPE)"
                rm -f "$OUTPUT_FILE"
            fi
        else
            echo "✗ Empty file: $LINK"
            rm -f "$OUTPUT_FILE"
        fi
    else
        echo "✗ Failed: $LINK"
        rm -f "$OUTPUT_FILE"
    fi

    COUNTER=$((COUNTER + 1))

    # Small delay between downloads
    sleep 2
done

echo ""
echo "Download complete!"
echo "Successfully downloaded: $SUCCESS_COUNT files"
echo "Files saved in: $DOWNLOAD_DIR/"
