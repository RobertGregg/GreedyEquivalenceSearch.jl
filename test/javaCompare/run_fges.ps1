# =============================================================================
# Run FGES (causal-cmd) on all simulated DAG datasets
# =============================================================================
# Usage: .\run_fges.ps1
# Optional overrides (pass from terminal):
#   .\run_fges.ps1 -PenaltyDiscount 2.0 -NumThreads 8
# =============================================================================

param(
    [string]$JarPath         = "causal-cmd-7.6.8-jar-with-dependencies.jar",
    [string]$DataDir         = "simulatedDAGs",
    [string]$OutputDir       = "fges_outputs",
    [double]$PenaltyDiscount = 1.0,
    [int]   $NumThreads      = 14,
    [string]$Verbose         = "Yes"
)

# --- 0. Sanity checks --------------------------------------------------------
if (-not (Test-Path $JarPath)) {
    Write-Error "JAR not found: $JarPath"
    exit 1
}
if (-not (Test-Path $DataDir)) {
    Write-Error "Data directory not found: $DataDir"
    exit 1
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# --- 1. Collect all data CSVs ------------------------------------------------
$csvFiles = Get-ChildItem -Path $DataDir -Filter "dag_data_*.csv" | Sort-Object Name

if ($csvFiles.Count -eq 0) {
    Write-Error "No dag_data_*.csv files found in '$DataDir'."
    exit 1
}

Write-Host "Found $($csvFiles.Count) dataset(s) in '$DataDir'." -ForegroundColor Cyan
Write-Host "Outputs will be saved to '$OutputDir'." -ForegroundColor Cyan
Write-Host ""

# --- 2. Track results --------------------------------------------------------
$results  = [System.Collections.Generic.List[PSCustomObject]]::new()
$total    = $csvFiles.Count
$success  = 0
$failed   = 0
$start    = Get-Date

# --- 3. Main loop ------------------------------------------------------------
for ($i = 0; $i -lt $csvFiles.Count; $i++) {
    $file   = $csvFiles[$i]
    # Extract the zero-padded ID from the filename (e.g. "0001")
    $id     = $file.BaseName -replace "dag_data_", ""
    $prefix = Join-Path $OutputDir "output_$id"
    $num    = $i + 1

    Write-Host "[$num/$total] $($file.Name) ..." -NoNewline

    $argList = @(
        "-jar", $JarPath,
        "--dataset",         "`"$($file.FullName)`"",
        "--algorithm",       "FGES",
        "--delimiter",       "comma",
        "--data-type",       "continuous",
        "--score",           "sem-bic-score",
        "--prefix",          $prefix,
        "--penaltyDiscount", $PenaltyDiscount,
        "--numThreads",      $NumThreads,
        "--verbose",         $Verbose
    )

    $t0      = Get-Date
    $process = Start-Process -FilePath "java" `
                             -ArgumentList $argList `
                             -Wait -PassThru -NoNewWindow `
                             -RedirectStandardOutput "$prefix.stdout.txt" `
                             -RedirectStandardError  "$prefix.stderr.txt"
    $elapsed = (Get-Date) - $t0

    $ok = $process.ExitCode -eq 0

    if ($ok) {
        $success++
        Write-Host " OK ($([math]::Round($elapsed.TotalSeconds, 1))s)" -ForegroundColor Green
    } else {
        $failed++
        Write-Host " FAILED (exit $($process.ExitCode))" -ForegroundColor Red
        Write-Host "  See: $prefix.stderr.txt" -ForegroundColor Yellow
    }

    $results.Add([PSCustomObject]@{
        id             = $id
        dataset        = $file.Name
        exit_code      = $process.ExitCode
        success        = $ok
        elapsed_sec    = [math]::Round($elapsed.TotalSeconds, 2)
        penaltyDiscount = $PenaltyDiscount
        numThreads     = $NumThreads
        prefix         = $prefix
    })
}

# --- 4. Summary --------------------------------------------------------------
$totalElapsed = (Get-Date) - $start
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " Completed $total run(s) in $([math]::Round($totalElapsed.TotalMinutes, 1)) min" -ForegroundColor Cyan
Write-Host " Succeeded : $success" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host " Failed    : $failed" -ForegroundColor Red
} else {
    Write-Host " Failed    : $failed" -ForegroundColor Green
}
Write-Host "=====================================================" -ForegroundColor Cyan

# --- 5. Save run log ---------------------------------------------------------
$logPath = Join-Path $OutputDir "fges_run_log.csv"
$results | Export-Csv -Path $logPath -NoTypeInformation
Write-Host "Run log saved to: $logPath" -ForegroundColor Cyan
