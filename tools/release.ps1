<#
.SYNOPSIS
  Build exe Windows (Godot export) lalu upload ke GitHub Releases untuk auto-updater.

.DESCRIPTION
  1. Baca versi dari project.godot (application/config/version)
  2. Export "Windows Desktop" (release, PCK ter-embed -> satu file .exe)
  3. Zip jadi AIO-Parser-windows.zip (nama asset ini yang dicari UpdateManager)
  4. Buat / update GitHub release v<versi> dan upload zip

  Tanpa -Publish release dibuat sebagai DRAFT: tidak terlihat publik dan tag git
  belum dibuat. Publish SETELAH commit versi ini sudah di-push, supaya tag
  menunjuk ke source yang sama dengan build:
      .\tools\release.ps1 -Publish -Target <commit-sha>

.PARAMETER Publish
  Publish release (bukan draft).
.PARAMETER Target
  Commit SHA/branch yang dijadikan tag. Hanya berpengaruh saat tag belum ada.
.PARAMETER Notes
  Isi release notes (tampil di dialog update di aplikasi).
#>
param(
	[string]$GodotExe = 'D:\Godot\4.5\Godot_v4.5-stable_win64_console.exe',
	[string]$Repo = 'BlueMiku/csv-parsing',
	[string]$Notes = '',
	[string]$Target = '',
	[switch]$Publish
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$projectFile = Join-Path $root 'project.godot'

if (-not (Test-Path $GodotExe)) { throw "Godot tidak ditemukan di $GodotExe (pakai -GodotExe)." }

# 1. Versi
$versionMatch = Select-String -Path $projectFile -Pattern '^config/version="([^"]+)"' | Select-Object -First 1
if (-not $versionMatch) { throw 'config/version tidak ada di project.godot.' }
$version = $versionMatch.Matches[0].Groups[1].Value
$tag = "v$version"
Write-Host "Versi: $version  (tag $tag)"

# 2. Export
$outDir = Join-Path (Split-Path -Parent $root) "CSV parsing exxports\release-$tag"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$exePath = Join-Path $outDir 'AIO Parser.exe'
if (Test-Path $exePath) { Remove-Item $exePath -Force }

if (-not (Test-Path (Join-Path $root '.godot\imported'))) {
	Write-Host 'Import resource dulu...'
	& $GodotExe --headless --path $root --import | Out-Null
}

Write-Host "Export ke $exePath ..."
& $GodotExe --headless --path $root --export-release 'Windows Desktop' $exePath
if (-not (Test-Path $exePath)) { throw 'Export gagal: exe tidak terbentuk.' }
Write-Host ("Exe: {0:N1} MB" -f ((Get-Item $exePath).Length / 1MB))

# 3. Zip (nama asset harus berakhiran -windows.zip)
$zipPath = Join-Path $outDir 'AIO-Parser-windows.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $exePath -DestinationPath $zipPath
Write-Host "Zip: $zipPath"

# 4. GitHub release
if (-not $Notes) { $Notes = "AIO Parser $tag" }

$existing = gh release list --repo $Repo --json tagName,isDraft --limit 100 | ConvertFrom-Json |
	Where-Object { $_.tagName -eq $tag } | Select-Object -First 1

if ($existing) {
	Write-Host "Release $tag sudah ada (draft=$($existing.isDraft)), upload ulang asset..."
	gh release upload $tag $zipPath --repo $Repo --clobber
	if ($LASTEXITCODE -ne 0) { throw 'gh release upload gagal.' }
	$editArgs = @('release', 'edit', $tag, '--repo', $Repo, '--notes', $Notes)
	if ($Publish) { $editArgs += '--draft=false' }
	if ($Target) { $editArgs += @('--target', $Target) }
	gh @editArgs
	if ($LASTEXITCODE -ne 0) { throw 'gh release edit gagal.' }
} else {
	$createArgs = @('release', 'create', $tag, $zipPath, '--repo', $Repo, '--title', $tag, '--notes', $Notes)
	if (-not $Publish) { $createArgs += '--draft' }
	if ($Target) { $createArgs += @('--target', $Target) }
	gh @createArgs
	if ($LASTEXITCODE -ne 0) { throw 'gh release create gagal.' }
}

gh release view $tag --repo $Repo --json url,isDraft,assets --jq '{url, isDraft, assets: [.assets[].name]}'
