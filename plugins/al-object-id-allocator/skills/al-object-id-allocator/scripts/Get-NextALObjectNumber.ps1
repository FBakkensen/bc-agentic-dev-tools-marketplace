<#
.SYNOPSIS
    Allocates next available AL object number for Business Central development.

.DESCRIPTION
    Parses app.json idRanges and .al files in a specified AL app folder to find
    the next available object number for a given object type. Prioritizes gaps
    in the number sequence over sequential allocation.

.PARAMETER AppPath
    Absolute or relative path to an AL app folder containing app.json.
    The folder must exist and contain a valid app.json file in its root.

.PARAMETER ObjectType
    Type of AL object to allocate a number for. Accepted values (case-insensitive):
    table, page, codeunit, report, query, xmlport, enum, interface, controladdin,
    pageextension, pagecustomization, tableextension, enumextension, reportextension,
    permissionset, entitlement, profile

.OUTPUTS
    System.Int32. Returns the next available object number to stdout.
    Writes errors to stderr with format: ERROR-XXX: <message>

.EXAMPLE
    .\Get-NextALObjectNumber.ps1 -AppPath ".\app" -ObjectType "table"
    Returns the next available table number from the app folder.

.EXAMPLE
    $nextNumber = .\Get-NextALObjectNumber.ps1 -AppPath ".\test" -ObjectType "codeunit"
    Captures the next available test codeunit number in a variable.

.NOTES
    Version: 1.0
    Date: 2025-11-10
    Exit Codes:
        0 = Success (valid number returned)
        1 = Error (see ERROR-XXX codes in stderr)

    Error Codes:
        ERROR-001: No app.json found in specified folder
        ERROR-002: Invalid JSON in app.json or missing idRanges
        ERROR-003: No available numbers in allowed ranges
        ERROR-004: Specified folder path does not exist
        ERROR-005: Invalid or unsupported object type
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Path to AL app folder containing app.json")]
    [string]$AppPath,

    [Parameter(Mandatory=$true, HelpMessage="AL object type (e.g., table, page, codeunit)")]
    [string]$ObjectType
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper Functions

<#
.SYNOPSIS
    Writes an error message to stderr and exits with code 1.
.DESCRIPTION
    Helper function to output structured error messages to stderr stream
    without throwing a terminating exception.
#>
function Write-ScriptError {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $host.UI.WriteErrorLine($Message)
    exit 1
}

<#
.SYNOPSIS
    Removes AL comments from source code.
.DESCRIPTION
    Removes both single-line (//) and block (/* */) comments from AL source code
    to prevent commented-out object declarations from being detected.
#>
function Remove-ALComments {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content
    )

    # Remove block comments /* ... */ (non-greedy to handle multiple blocks)
    $Content = $Content -replace '/\*[\s\S]*?\*/', ''

    # Remove single-line comments // (use multiline regex)
    $Content = $Content -replace '(?m)//.*$', ''

    return $Content
}

#endregion

#region Parameter Validation (T004)

# Supported object types (case-insensitive)
$SupportedObjectTypes = @(
    'table', 'page', 'codeunit', 'report', 'query', 'xmlport', 'enum',
    'interface', 'controladdin', 'pageextension', 'tableextension',
    'enumextension', 'reportextension', 'permissionset', 'entitlement',
    'profile', 'pagecustomization'
)

# Validate ObjectType (ERROR-005)
$ObjectTypeLower = $ObjectType.ToLower()
if ($SupportedObjectTypes -notcontains $ObjectTypeLower) {
    Write-ScriptError "ERROR-005: Invalid or unsupported object type: $ObjectType"
}

# Validate AppPath exists (ERROR-004)
if (-not (Test-Path -Path $AppPath -PathType Container)) {
    Write-ScriptError "ERROR-004: Specified folder path does not exist: $AppPath"
}

# Resolve to absolute path for consistency
$AppPath = Resolve-Path -Path $AppPath

#endregion

#region app.json Discovery and Validation (T005, T006)

$appJsonPath = Join-Path -Path $AppPath -ChildPath "app.json"

# Validate app.json exists (ERROR-001)
if (-not (Test-Path -Path $appJsonPath -PathType Leaf)) {
    Write-ScriptError "ERROR-001: No app.json found in specified folder: $AppPath"
}

# Parse app.json (ERROR-002)
try {
    $appJsonContent = Get-Content -Path $appJsonPath -Raw
    $appJson = $appJsonContent | ConvertFrom-Json

    # Validate idRanges property exists
    if (-not ($appJson.PSObject.Properties.Name -contains 'idRanges')) {
        Write-ScriptError "ERROR-002: Invalid JSON in app.json - missing idRanges property"
    }

    # Validate idRanges is an array with elements
    if ($null -eq $appJson.idRanges -or @($appJson.idRanges).Count -eq 0) {
        Write-ScriptError "ERROR-002: Invalid JSON in app.json - idRanges is empty or null"
    }
} catch {
    Write-ScriptError "ERROR-002: Invalid JSON in app.json - $($_.Exception.Message)"
}

#endregion

#region AL File Discovery (T007)

# Find all .al files recursively
$alFiles = Get-ChildItem -Path $AppPath -Recurse -Filter "*.al" -File

#endregion

#region Object Number Extraction (T008, T009)

# Build regex pattern for object type (case-insensitive)
# Pattern: ^\s*<objecttype>\s+(\d+)\s+
$pattern = "(?mi)^\s*$ObjectTypeLower\s+(\d+)\s+"

# Use Select-String for efficient file scanning
# This avoids loading full content for files without matches
$usedNumbers = $alFiles | Select-String -Pattern $pattern -AllMatches | ForEach-Object {
    # For each file with matches, process to handle comments
    $file = Get-Item $_.Path
    try {
        $fileContent = Get-Content -Path $file.FullName -Raw

        # Remove comments to avoid false positives
        $cleanContent = Remove-ALComments -Content $fileContent

        # Re-extract numbers from cleaned content to ensure accuracy
        $regex = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Compiled)
        $matches = $regex.Matches($cleanContent)
        foreach ($match in $matches) {
            [int]$match.Groups[1].Value
        }
    } catch {
        # Best-effort parsing - skip malformed files
        Write-Verbose "Warning: Could not parse file $($file.FullName): $($_.Exception.Message)"
    }
} | Select-Object -Unique

# Handle case where no files match
if ($null -eq $usedNumbers) {
    $usedNumbers = @()
}

#endregion

#region Build Allowed Numbers Set (Foundation for gap-filling)

# Build complete list of all allowed numbers from all idRanges
$allowedNumbers = @()

foreach ($range in $appJson.idRanges) {
    # Validate range has from and to properties
    if ($null -eq $range.from -or $null -eq $range.to) {
        Write-Verbose "Warning: Skipping invalid range in app.json (missing from/to)"
        continue
    }

    # Add all numbers in this range efficiently
    $allowedNumbers += $range.from..$range.to
}

#endregion

#region Calculate Available Numbers and Return Result

# Find available numbers (allowed - used)
$availableNumbers = $allowedNumbers | Where-Object { $usedNumbers -notcontains $_ }

if ($availableNumbers.Count -eq 0) {
    Write-ScriptError "ERROR-003: No available numbers in allowed ranges"
}

# Return the minimum available number (gap-filling priority)
$nextNumber = ($availableNumbers | Measure-Object -Minimum).Minimum
Write-Output $nextNumber
exit 0

#endregion
