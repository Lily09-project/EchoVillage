$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$required = @('project.godot','scenes\main\Main.tscn','scripts\main.gd','scripts\core\game_manager.gd','scripts\save\save_manager.gd','tests\test_runner.gd','tests\TestRunner.tscn','tests\soak_runner.gd','tests\SoakRunner.tscn','run_echo_village.bat','build_release.bat','tools\run_godot_bounded.ps1','tools\run_nightly_soak.ps1','tools\security_audit.ps1','.github\workflows\ci.yml','.github\workflows\nightly-soak.yml','data\npcs\npc_profiles.json','data\items\items.json','data\items\recipes.json','data\dialogue\templates.json','data\events\world_events.json','data\world\locations.json','data\quests\quests.json','quality\test-manifest.json','quality\test-manifest.schema.json','quality\acceptance-report.schema.json','quality\run_acceptance.ps1')
$issues = @()
foreach($relative in $required){ if(-not (Test-Path -LiteralPath (Join-Path $root $relative))){ $issues += "Missing: $relative" } }
Get-ChildItem -LiteralPath (Join-Path $root 'data') -Recurse -Filter *.json | ForEach-Object {
  try { Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName | ConvertFrom-Json | Out-Null } catch { $issues += "Invalid JSON: $($_.FullName)" }
}
$profiles = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'data\npcs\npc_profiles.json') | ConvertFrom-Json
if($profiles.npcs.Count -ne 5){ $issues += 'Expected exactly five NPC profiles.' }
foreach($npc in $profiles.npcs){ foreach($field in @('id','display_name','occupation','personality','base_schedule','starting_inventory')){ if($null -eq $npc.$field){ $issues += "NPC $($npc.id) lacks $field" } } }
$items = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'data\items\items.json') | ConvertFrom-Json
$locationData = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'data\world\locations.json') | ConvertFrom-Json
$questData = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'data\quests\quests.json') | ConvertFrom-Json
$recipeData = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'data\items\recipes.json') | ConvertFrom-Json
$locationIds = @($locationData.locations | ForEach-Object { [string]$_.id })
if($locationIds.Count -ne @($locationIds | Select-Object -Unique).Count){ $issues += 'Location IDs must be unique.' }
foreach($location in $locationData.locations){
  foreach($field in @('id','display_name','bounds','neighbors','unlock_requirements','landmark_ids')){ if($null -eq $location.$field){ $issues += "Location $($location.id) lacks $field" } }
  foreach($neighbor in @($location.neighbors)){ if($locationIds -notcontains [string]$neighbor){ $issues += "Location $($location.id) references unknown neighbor $neighbor" } }
}
$npcIds = @($profiles.npcs | ForEach-Object { [string]$_.id })
$questIds = @($questData.quests | ForEach-Object { [string]$_.id })
if($questIds.Count -ne @($questIds | Select-Object -Unique).Count){ $issues += 'Quest IDs must be unique.' }
$supportedObjectives = @('talk_to_npc','deliver_item','visit_location','reach_relationship')
foreach($quest in $questData.quests){
  foreach($field in @('id','title','giver_id','prerequisites','objectives','rewards','on_complete_flags')){ if($null -eq $quest.$field){ $issues += "Quest $($quest.id) lacks $field" } }
  if($npcIds -notcontains [string]$quest.giver_id){ $issues += "Quest $($quest.id) references unknown giver $($quest.giver_id)" }
  foreach($objective in @($quest.objectives)){
    if($supportedObjectives -notcontains [string]$objective.kind){ $issues += "Quest $($quest.id) has unsupported objective $($objective.kind)" }
    if([int]$objective.amount -lt 1){ $issues += "Quest $($quest.id) objective amount must be positive" }
    if($objective.kind -eq 'talk_to_npc' -and $npcIds -notcontains [string]$objective.target_id){ $issues += "Quest $($quest.id) references unknown NPC $($objective.target_id)" }
    if($objective.kind -eq 'visit_location' -and $locationIds -notcontains [string]$objective.target_id){ $issues += "Quest $($quest.id) references unknown location $($objective.target_id)" }
    if($objective.kind -eq 'deliver_item' -and $null -eq $items.PSObject.Properties[[string]$objective.target_id]){ $issues += "Quest $($quest.id) references unknown item $($objective.target_id)" }
  }
}
foreach($recipe in $recipeData.recipes){
  if([int]$recipe.output_amount -lt 1){ $issues += "Recipe $($recipe.id) output amount must be positive" }
  if($null -eq $items.PSObject.Properties[[string]$recipe.output_item]){ $issues += "Recipe $($recipe.id) references unknown output item $($recipe.output_item)" }
  if($locationIds -notcontains [string]$recipe.required_location){ $issues += "Recipe $($recipe.id) references unknown location $($recipe.required_location)" }
  foreach($property in $recipe.ingredients.PSObject.Properties){ if($null -eq $items.PSObject.Properties[$property.Name] -or [int]$property.Value -lt 1){ $issues += "Recipe $($recipe.id) has invalid ingredient $($property.Name)" } }
}
$workflowPath = Join-Path $root '.github\workflows\ci.yml'
if(Test-Path -LiteralPath $workflowPath -PathType Leaf){
  $workflowText = Get-Content -Raw -Encoding UTF8 -LiteralPath $workflowPath
  $workflowRequired = @('name: Echo Village CI','pull_request:','workflow_dispatch:','permissions:','contents: read','runs-on: windows-latest','4.5.2-stable','GODOT_SHA512','Godot archive checksum mismatch.','gitleaks/gitleaks-action@e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e','GODOT_EXECUTABLE','run_echo_village.bat --test','actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a','tests/simulation_test_report.json','tests/security_audit_report.json','npc_decision_explanation.png','if: always()')
  foreach($token in $workflowRequired){ if($workflowText -notmatch [regex]::Escape($token)){ $issues += "CI workflow lacks required contract: $token" } }
  foreach($forbidden in @('TODO','TBD','YOUR_','CHANGE_ME')){ if($workflowText -match [regex]::Escape($forbidden)){ $issues += "CI workflow contains forbidden placeholder text: $forbidden" } }
}
$runnerPath = Join-Path $root 'tools\run_godot_bounded.ps1'
if(Test-Path -LiteralPath $runnerPath -PathType Leaf){
  $runnerText = Get-Content -Raw -Encoding UTF8 -LiteralPath $runnerPath
  foreach($token in @('taskkill.exe','/PID $ProcessId','/T /F','exit 124')){ if($runnerText -notmatch [regex]::Escape($token)){ $issues += "Bounded Godot runner lacks process cleanup contract: $token" } }
}
$nightlyWorkflowPath = Join-Path $root '.github\workflows\nightly-soak.yml'
if(Test-Path -LiteralPath $nightlyWorkflowPath -PathType Leaf){
  $nightlyWorkflowText = Get-Content -Raw -Encoding UTF8 -LiteralPath $nightlyWorkflowPath
  $nightlyWorkflowRequired = @('name: Echo Village Nightly Soak','schedule:','workflow_dispatch:','permissions:','contents: read','runs-on: windows-latest','4.5.2-stable','GODOT_SHA512','Godot archive checksum mismatch.','GODOT_EXECUTABLE','quality\run_acceptance.ps1 nightly','actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a','tests/soak_test_report.json','reports/acceptance/','if: always()')
  foreach($token in $nightlyWorkflowRequired){ if($nightlyWorkflowText -notmatch [regex]::Escape($token)){ $issues += "Nightly workflow lacks required contract: $token" } }
  foreach($forbidden in @('TODO','TBD','YOUR_','CHANGE_ME')){ if($nightlyWorkflowText -match [regex]::Escape($forbidden)){ $issues += "Nightly workflow contains forbidden placeholder text: $forbidden" } }
}
$launcherPath = Join-Path $root 'run_echo_village.bat'
if(Test-Path -LiteralPath $launcherPath -PathType Leaf){
  $launcherText = Get-Content -Raw -Encoding UTF8 -LiteralPath $launcherPath
  foreach($token in @('SCRIPT ERROR','ERROR: Failed to load script','ObjectDB instances leaked','TEST_RESULT passed=','failed=0','--help','does not support argument','exit /b 2')){ if($launcherText -notmatch [regex]::Escape($token)){ $issues += "Test launcher lacks required failure gate: $token" } }
}
$releasePath = Join-Path $root 'build_release.bat'
if(Test-Path -LiteralPath $releasePath -PathType Leaf){
  $releaseText = Get-Content -Raw -Encoding UTF8 -LiteralPath $releasePath
  foreach($token in @('GODOT_EXECUTABLE','GODOT_RUNTIME','--export-pack','SMOKE_LOG','Invalid wrapper executable name')){ if($releaseText -notmatch [regex]::Escape($token)){ $issues += "Release builder lacks delivery contract: $token" } }
}
$qualityDirectory = Join-Path $root 'quality'
Get-ChildItem -LiteralPath $qualityDirectory -Filter *.json -File | ForEach-Object {
  try { Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName | ConvertFrom-Json | Out-Null } catch { $issues += "Invalid quality JSON: $($_.Name)" }
}
$manifestPath = Join-Path $qualityDirectory 'test-manifest.json'
if(Test-Path -LiteralPath $manifestPath -PathType Leaf){
  $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
  if($manifest.schema_version -ne '1.0'){ $issues += 'Acceptance manifest schema_version must be 1.0.' }
  if($manifest.project -ne 'EchoVillage'){ $issues += 'Acceptance manifest project must be EchoVillage.' }
  $manifestProfiles = @($manifest.profiles)
  if($manifestProfiles.Count -eq 0 -or $manifestProfiles.Count -ne @($manifestProfiles | Select-Object -Unique).Count){ $issues += 'Acceptance profiles must be non-empty and unique.' }
  $gateIds = @($manifest.gates | ForEach-Object { [string]$_.id })
  if($gateIds.Count -eq 0 -or $gateIds.Count -ne @($gateIds | Select-Object -Unique).Count){ $issues += 'Acceptance gate IDs must be non-empty and unique.' }
  foreach($gate in $manifest.gates){
    if($gate.type -ne 'command'){ $issues += "Acceptance gate $($gate.id) must use command type." }
    if(@($gate.command).Count -eq 0){ $issues += "Acceptance gate $($gate.id) must define a command." }
    if([int]$gate.timeout_seconds -lt 1 -or [int]$gate.timeout_seconds -gt 7200){ $issues += "Acceptance gate $($gate.id) has an invalid timeout." }
    foreach($profile in @($gate.profiles)){ if($manifestProfiles -notcontains $profile){ $issues += "Acceptance gate $($gate.id) references unknown profile $profile." } }
  }
}
$acceptanceRunnerPath = Join-Path $qualityDirectory 'run_acceptance.ps1'
if(Test-Path -LiteralPath $acceptanceRunnerPath -PathType Leaf){
  $acceptanceRunnerText = Get-Content -Raw -Encoding UTF8 -LiteralPath $acceptanceRunnerPath
  foreach($token in @('WaitForExit','Stop-ProcessTree','taskkill.exe','timed_out','acceptance-report.json','manifest_sha256','required evidence missing','required evidence not refreshed','Get-FileHash','size_bytes','modified_at')){ if($acceptanceRunnerText -notmatch [regex]::Escape($token)){ $issues += "Acceptance runner lacks required contract: $token" } }
}
$soakRunnerPath = Join-Path $root 'tests\soak_runner.gd'
if(Test-Path -LiteralPath $soakRunnerPath -PathType Leaf){
  $soakRunnerText = Get-Content -Raw -Encoding UTF8 -LiteralPath $soakRunnerPath
  foreach($token in @('DAYS := 90','MEMORY_STATIC','MAX_SAVE_BYTES','MAX_MEMORY_GROWTH_BYTES','MAX_FINAL_SEGMENT_RATIO','SOAK_RESULT','soak_test_report.json')){ if($soakRunnerText -notmatch [regex]::Escape($token)){ $issues += "Nightly soak lacks required contract: $token" } }
}
if($issues.Count -gt 0){ $issues | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output "PASS: structural and JSON validation completed for $root"
