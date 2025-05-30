# File Type Downloader

This tool helps you find and download files from the internet based on your search keywords and file type preferences. It leverages Google Custom Search API to locate files matching your criteria and downloads them to a specified directory on your local machine.

The script is a versatile command-line tool for researchers, students, and professionals who need to collect multiple documents of a specific format (PDFs, Word documents, spreadsheets, etc.) related to a particular topic. It automates what would otherwise be a tedious manual process of searching and downloading files one by one.

## Prerequisites

Before using this script, you need to:

1. **Get a Google API Key**:
- Visit [Google Custom Search API](https://developers.google.com/custom-search/v1/introduction)
- Click "Get a Key" and follow the instructions
- Free tier allows 100 search queries per day

2. **Create a Custom Search Engine ID**:
- Visit [Programmable Search Engine](https://programmablesearchengine.google.com/controlpanel/create)
- Create a new search engine
- Make sure to check "Search the entire web" in the settings

## Script parameters

Both scripts take six parameters:
- `search keyword(s)` - The search term in quotes
- `filetype` - The file type extension (pdf, docx, xlsx, etc.)
- `download_directory` - Where to save the downloaded files
- `number_of_files` - Maximum number of files to download
- `api_key` - Your Google Custom Search API key
- `search_engine_id` - Your Custom Search Engine ID

## How to use

### On Linux/macOS (Shell Script)

To use the bash script:
1. Save it as `downloader.sh`
2. Make it executable with: `chmod +x downloader.sh`
3. Run it with the required parameters: `./downloader.sh "search keywords" filetype download_directory number_of_files YOUR_API_KEY YOUR_SEARCH_ENGINE_ID`

### On Windows (PowerShell Script)

To use the PowerShell script:
1. Save it as `downloader.ps1`
2. Run the script with the required parameters:
   ```powershell
   .\downloader.ps1 -Keyword "search keywords" -FileType filetype -DownloadDirectory download_directory -NumberOfFiles number_of_files -ApiKey YOUR_API_KEY -SearchEngineId YOUR_SEARCH_ENGINE_ID
   ```

## Examples

### Linux/macOS Example
- Download up to 50 PowerPoint presentations about marketing strategy to the "presentations" directory
    ```shell
    ./downloader.sh "digital marketing strategies" pptx presentations 50 YOUR_API_KEY YOUR_SEARCH_ENGINE_ID
    ```

### Windows Example
- Download up to 10 Word documents containing resume examples to the "resumes" directory
    ```powershell
    .\downloader.ps1 -Keyword "resume examples" -FileType docx -DownloadDirectory resumes -NumberOfFiles 10 -ApiKey YOUR_API_KEY -SearchEngineId YOUR_SEARCH_ENGINE_ID
    ```

## Features

- Uses official Google Custom Search API for reliable results
- File type verification ensures downloaded files match the requested format
- Progress tracking shows download status in real-time
- Automatic file renaming prevents file name conflicts
- Error handling for failed downloads and incorrect file types
- Cross-platform support (Linux, macOS, and Windows)

## Limitations

- Google Custom Search API free tier is limited to 100 search queries per day
- Each search can return a maximum of 10 results per request (up to 100 total with pagination)
- Beyond the free tier, the API costs $5 per 1000 queries (check the current pricing on Google)

## Notes

- Files are saved with a numerical prefix to ensure uniqueness
- The Linux/macOS script requires `curl` and `jq` commands installed
- The Windows script requires PowerShell 3.0 or later