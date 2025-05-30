<#
.SYNOPSIS
    Downloads files of a specific type based on search keywords using Google Custom Search API.
.DESCRIPTION
    This PowerShell script helps you find and download files from the internet based on
    your search keywords and file type preferences. It leverages Google Custom Search API
    to locate files matching your criteria and downloads them to a specified directory.
.PARAMETER Keyword
    The search term to find files
.PARAMETER FileType
    The file type extension (pdf, docx, xlsx, etc.)
.PARAMETER DownloadDirectory
    Where to save the downloaded files
.PARAMETER NumberOfFiles
    Maximum number of files to download
.PARAMETER ApiKey
    Your Google Custom Search API key
.PARAMETER SearchEngineId
    Your Custom Search Engine ID
.EXAMPLE
    .\downloader.ps1 -Keyword "digital marketing strategies" -FileType pptx -DownloadDirectory presentations -NumberOfFiles 50 -ApiKey YOUR_API_KEY -SearchEngineId YOUR_SEARCH_ENGINE_ID
.NOTES
    To get API key: https://developers.google.com/custom-search/v1/introduction
    To create a search engine ID: https://programmablesearchengine.google.com/controlpanel/create
#>

param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Keyword,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$FileType,

    [Parameter(Mandatory=$true, Position=2)]
    [string]$DownloadDirectory,

    [Parameter(Mandatory=$true, Position=3)]
    [int]$NumberOfFiles,

    [Parameter(Mandatory=$true, Position=4)]
    [string]$ApiKey,

    [Parameter(Mandatory=$true, Position=5)]
    [string]$SearchEngineId
)

# Validate input
if ($NumberOfFiles -le 0) {
    Write-Host "Error: Number of files must be a positive integer"
    exit 1
}

if ([string]::IsNullOrEmpty($Keyword) -or [string]::IsNullOrEmpty($FileType) -or
    [string]::IsNullOrEmpty($DownloadDirectory) -or [string]::IsNullOrEmpty($ApiKey) -or
    [string]::IsNullOrEmpty($SearchEngineId)) {
    Write-Host "Error: All parameters are required"
    Get-Help $MyInvocation.MyCommand.Path
    exit 1
}

# Create download directory if it doesn't exist
if (-not (Test-Path -Path $DownloadDirectory)) {
    try {
        New-Item -ItemType Directory -Path $DownloadDirectory -Force | Out-Null
    }
    catch {
        Write-Host "Error: Cannot create directory $DownloadDirectory"
        exit 1
    }
}

Write-Host "Searching for $FileType files with keyword `"$Keyword`" using Google Custom Search API..."

# Calculate how many API requests we need (Google CSE returns max 10 results per request)
$MaxPerRequest = 10
$RequestsNeeded = [Math]::Ceiling($NumberOfFiles / $MaxPerRequest)
if ($RequestsNeeded -gt 10) {
    # Google CSE free tier limits to 100 results (10 requests of 10 results each)
    Write-Host "Warning: Google CSE API limits free tier to 100 results. Limiting requests to 10."
    $RequestsNeeded = 10
}

# Initialize an empty array for file links
$allLinks = @()

# Perform the search requests
for ($i = 0; $i -lt $RequestsNeeded; $i++) {
    $startIndex = ($i * $MaxPerRequest) + 1

    # URL encode the search query
    $encodedQuery = [System.Web.HttpUtility]::UrlEncode($Keyword)

    # Construct the API URL
    $apiUrl = "https://customsearch.googleapis.com/customsearch/v1?cx=$SearchEngineId&fileType=$FileType&key=$ApiKey&&q=$encodedQuery&fileType=$FileType&start=$startIndex"

    Write-Host "Fetching results page $($i+1)..."

    # Call the Google Custom Search API
    try {
        $searchResults = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
    }
    catch {
        Write-Host "Error: Failed to fetch search results from Google API"
        Write-Host "Request: $apiUrl"
        Write-Host "Error: $_"
        break
    }

    # Check for API errors
    if ($searchResults.error) {
        Write-Host "API Error: $($searchResults.error.message)"
        Write-Host "Please check your API key and search engine ID"
        exit 1
    }

    # Extract file links from the response
    if ($searchResults.items) {
        foreach ($item in $searchResults.items) {
            # Only add links that end with the specified file type
            if ($item.link -like "*.$FileType*") {
                $allLinks += $item.link
            }
        }
    }

    if ($allLinks.Count -ge $NumberOfFiles) {
        break
    }

    # Small delay between API requests to be nice
    Start-Sleep -Seconds 2
}

# Count found links
$linkCount = $allLinks.Count

if ($linkCount -eq 0) {
    Write-Host "No $FileType files found for keyword `"$Keyword`""
    Write-Host "Try using different keywords or file type"
    exit 1
}

Write-Host "Found $linkCount files. Starting download..."

# Download each file
$counter = 1
$successCount = 0

foreach ($link in $allLinks) {
    # Generate safe filename
    $filename = Split-Path -Path $link -Leaf
    $filename = [Regex]::Replace($filename, '[^\w.-]', '_')
    if ([string]::IsNullOrEmpty($filename) -or $filename -eq "_") {
        $filename = "file_${counter}.$FileType"
    }

    # Truncate filename if too long
    if ($filename.Length -gt 50) {
        $filename = $filename.Substring(0, 50)
    }

    $outputFile = Join-Path -Path $DownloadDirectory -ChildPath "${counter}_${filename}"

    Write-Host "[$counter/$linkCount] Downloading: $(Split-Path -Path $link -Leaf)"

    # Download with error handling
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        $webClient.DownloadFile($link, $outputFile)

        # Verify file was downloaded and has content
        if ((Test-Path -Path $outputFile) -and (Get-Item -Path $outputFile).Length -gt 0) {
            # PowerShell doesn't have a direct 'file' command equivalent,
            # so we'll do a simple check if the file exists and has content
            $fileSize = (Get-Item -Path $outputFile).Length / 1KB
            $fileSizeFormatted = "{0:N2} KB" -f $fileSize
            Write-Host "✓ Downloaded: $outputFile ($fileSizeFormatted)"
            $successCount++
        }
        else {
            Write-Host "✗ Empty file: $link"
            if (Test-Path -Path $outputFile) {
                Remove-Item -Path $outputFile -Force
            }
        }
    }
    catch {
        Write-Host "✗ Failed: $link"
        Write-Host "  Error: $_"
        if (Test-Path -Path $outputFile) {
            Remove-Item -Path $outputFile -Force
        }
    }

    $counter++

    # Small delay between downloads
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Download complete!"
Write-Host "Successfully downloaded: $successCount files"
Write-Host "Files saved in: $DownloadDirectory\"