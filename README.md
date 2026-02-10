# CIC Bash Scripts

Bash scripts for interacting with the [Hyland Content Intelligence](https://www.hyland.com/en/solutions/products/hyland-content-intelligence) API to upload files and request content enrichment.

## Overview

These scripts demonstrate how to:
- Authenticate with CIC using OAuth 2.0 client credentials
- Upload files to CIC storage using presigned URLs
- Request content enrichment (text metadata generation)
- Poll for processing results

## Files

- **cic-connection-script.sh** - Main script that orchestrates file upload and enrichment
- **cic-connection-script-utils.sh** - Utility functions for authentication and polling

## Prerequisites

- `bash` (tested on macOS)
- `curl` - for HTTP requests
- `jq` - for JSON parsing ([install instructions](https://stedolan.github.io/jq/download/))
- CIC account with enrichment API access

## Required Environment Variables

Before running the scripts, set these environment variables:

```bash
export CIC_AUTH_BASE_URL="https://your-auth-endpoint"
export CIC_ENRICHMENT_CLIENT_ID="your-client-id"
export CIC_ENRICHMENT_CLIENT_SECRET="your-client-secret"
export CIC_ENRICHMENT_BASE_URL="https://your-enrichment-endpoint"
```

### Example `.env` file

You can create a `.env` file and source it:

```bash
# .env
export CIC_AUTH_BASE_URL="https://auth.example.com"
export CIC_ENRICHMENT_CLIENT_ID="your-client-id"
export CIC_ENRICHMENT_CLIENT_SECRET="your-client-secret"
export CIC_ENRICHMENT_BASE_URL="https://api.example.com"
```

Then load it:
```bash
source .env
```

## Usage

### Basic Usage

1. Set the required environment variables
2. Edit the `FILE_PATH` variable in `cic-connection-script.sh` to point to your file
3. Run the script:

```bash
./cic-connection-script.sh
```

### Workflow

The script performs these steps:

1. **Authenticate** - Obtains a bearer token using client credentials
2. **Upload** - Gets a presigned URL and uploads the file
3. **Enrich** - Requests metadata extraction with custom instructions
4. **Poll** - Waits for results and displays the extracted metadata

### Customizing Metadata Extraction

The script includes detailed metadata extraction instructions for contract processing. You can modify the `METADATA_JSON` section in `cic-connection-script.sh` to customize:

- Metadata fields to extract
- Confidence thresholds
- Processing instructions
- Similar examples (k-similar metadata)

## Sample Files

The repository includes example file paths for testing. These reference sample documents with fake data for demonstration purposes.

## Output

The script outputs:
- Progress messages during execution
- Upload confirmation
- Processing ID
- Final enrichment results in JSON format

## Error Handling

The scripts include error handling for:
- Authentication failures (HTTP errors)
- Upload failures
- Processing timeouts (default: 60 seconds)
- Missing required parameters

## License

[Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)

