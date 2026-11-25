param(
  [ValidateSet('Install', 'Lint', 'Build', 'All')]
  [string]$Task = 'All',
  [string]$ProjectRoot = (Join-Path $PSScriptRoot '../..')
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
Set-Location -LiteralPath $projectRoot

function Require-Tool([string]$Name) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) { throw "Required HarmonyOS tool is missing: $Name. See docs/ci.md." }
  return $command
}

if ($Task -in @('Install', 'All')) {
  $ohpmCommand = Require-Tool 'ohpm'
  foreach ($moduleDirectory in @($projectRoot, (Join-Path $projectRoot 'entry'))) {
    Push-Location -LiteralPath $moduleDirectory
    try {
      & $ohpmCommand install --all
      if ($LASTEXITCODE -ne 0) { throw 'ohpm dependency installation failed.' }
    } finally {
      Pop-Location
    }
  }
}

if ($Task -in @('Lint', 'All')) {
  $linterCommand = Require-Tool 'codelinter'
  $reportDirectory = Join-Path $projectRoot '.local/ci/reports'
  New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
  $report = Join-Path $reportDirectory 'codelinter.json'
  if (Test-Path -LiteralPath $report) { Remove-Item -LiteralPath $report }
  # Code Linter 5.1.140 has no --exit-on option. Its process may exit zero
  # even when findings exist, so validate the report and tool diagnostics below.
  $linterOutput = @(& $linterCommand --config (Join-Path $projectRoot 'code-linter.json5') --product default --format json --output $report $projectRoot 2>&1)
  $linterExitCode = $LASTEXITCODE
  $linterOutput | ForEach-Object { Write-Host $_ }
  if ($linterExitCode -ne 0 -or ($linterOutput -join [Environment]::NewLine).Contains(([string][char]27) + '[31m')) {
    throw 'Code Linter could not complete. Inspect the codelinter artifact and workflow log.'
  }
  if (-not (Test-Path -LiteralPath $report -PathType Leaf) -or (Get-Item -LiteralPath $report).Length -eq 0) {
    throw 'Code Linter did not produce a report; the lint check cannot pass.'
  }
  $reportText = Get-Content -LiteralPath $report -Raw -Encoding UTF8
  if (-not $reportText.TrimStart().StartsWith('[')) { throw 'Unexpected Code Linter report format.' }
  # Wrapping preserves empty and single-element arrays on both Windows
  # PowerShell 5.1 and PowerShell 7.
  $parsedReport = ConvertFrom-Json -InputObject ('{"results":' + $reportText + '}') -ErrorAction Stop
  $entries = $parsedReport.results
  $errorCount = 0
  $warningCount = 0
  foreach ($entry in $entries) {
    if ($entry.filePath -isnot [string] -or $entry.messages -isnot [array]) { throw 'Unexpected Code Linter report entry.' }
    foreach ($message in $entry.messages) {
      if ($message.severity -notin @('error', 'warn', 'suggestion')) { throw 'Unknown Code Linter diagnostic severity.' }
      if ($message.severity -eq 'error') { $errorCount++ }
      if ($message.severity -eq 'warn') { $warningCount++ }
    }
  }
  Write-Output "Code Linter: $errorCount error(s), $warningCount warning(s)."
  if ($errorCount -gt 0) { throw 'Code Linter found error-level findings. Inspect the codelinter artifact.' }
}

if ($Task -in @('Build', 'All')) {
  $hvigorCommand = Require-Tool 'hvigorw'
  & $hvigorCommand clean --no-daemon
  if ($LASTEXITCODE -ne 0) { throw 'Hvigor clean failed.' }
  & $hvigorCommand --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
  if ($LASTEXITCODE -ne 0) { throw 'HarmonyOS HAP compilation failed.' }
  $artifactDirectory = Join-Path $projectRoot 'entry/build/default/outputs/default'
  $artifacts = @(Get-ChildItem -LiteralPath $artifactDirectory -Filter '*-unsigned.hap' -File -ErrorAction SilentlyContinue)
  if ($artifacts.Count -eq 0 -or @($artifacts | Where-Object { $_.Length -eq 0 }).Count -gt 0) {
    throw 'Compilation did not produce a nonempty unsigned HAP in the expected output directory.'
  }
  $artifacts | Select-Object Name, Length
}
