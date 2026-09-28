$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root '.github\workflows\ci.yml'
$workflow = Get-Content -Raw -Encoding UTF8 -LiteralPath $workflowPath

if ($workflow -notmatch 'run_visual_qa_matrix\.ps1') {
    throw 'CI must execute tools/run_visual_qa_matrix.ps1.'
}
if ($workflow -notmatch 'reports[\\/]visual_qa[\\/]matrix') {
    throw 'CI must retain the generated visual QA matrix as an artifact.'
}

Write-Output 'PASS: CI executes and preserves the multi-resolution visual QA matrix.'
