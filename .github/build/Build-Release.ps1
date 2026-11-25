#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$OutDirectory,[Parameter(Mandatory)][string]$PatcherExe)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'

New-Item -ItemType Directory -Force -Path $OutDirectory|Out-Null
$storeFolder=Join-Path $OutDirectory 'Store'
$patcherFolder=Join-Path $OutDirectory 'Patcher'
New-Item -ItemType Directory -Force -Path $storeFolder,$patcherFolder|Out-Null

# File IDs and hashes were validated in a previous Microsoft SFS acquisition experiment.
# Query the official current Microsoft SFS API rather than embedding expiring CDN URLs.
$items=@(
  [pscustomobject]@{Moniker='Microsoft.WindowsStore_22610.1401.10.0_neutral_~_8wekyb3d8bbwe';Filename='Microsoft.WindowsStore_22610.1401.10.0_neutral_~_8wekyb3d8bbwe.msixbundle';Hash='F6CD9691B2E7CF940537A8BFBDE5723F2F0B2DFE1BFC6BE812A0C1E3205CB6FA';Length=127744931},
  [pscustomobject]@{Moniker='Microsoft.VCLibs.140.00_14.0.33519.0_x64__8wekyb3d8bbwe';Filename='Microsoft.VCLibs.140.00_14.0.33519.0_x64__8wekyb3d8bbwe.appx';Hash='9C17B521F9D690A1F504DA5108ED6EEC5669EB3A8FD1331EEF43E40D84E74283';Length=896581},
  [pscustomobject]@{Moniker='Microsoft.UI.Xaml.2.8_8.2501.31001.0_x64__8wekyb3d8bbwe';Filename='Microsoft.UI.Xaml.2.8_8.2501.31001.0_x64__8wekyb3d8bbwe.appx';Hash='2E7C2397D95F415FF97E26E3A63D52BE4C2E4BE3F885517E522B8E94E37B4FE2';Length=4932370}
)
# Download exact package revisions through Microsoft Windows Update/Store endpoints.
# The SFS "GenerateDownloadInfo" route recently returned EXBH transport blocks
# instead of raw package bytes; use the pinned Microsoft WU/DisplayCatalog resolver.
$resolver=Join-Path $env:RUNNER_TEMP 'Get-MSStoreDownloadLinks.ps1'
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/1NobleCyber/Get-MSStoreDownloadLinks/26510d1de601fbb76a7e124188a805abac235f64/Get-MSStoreDownloadLinks.ps1' -OutFile $resolver -ErrorAction Stop
$blobHash=((git hash-object $resolver) | Select-Object -First 1).Trim()
if($blobHash -ne '12c6ef8c9bb905bf9bf322d37c9b06da64cd6e2a'){throw "Pinned Store link resolver Git SHA1 mismatch: $blobHash"}
$links=@(& $resolver -ProductId '9WZDNCRFJBMP' -Locale en-US -OSSKUId 48 -OSVersion '10.0.20348.1')
if(-not $links){throw 'Windows Update Store link resolver returned no packages'}
Write-Host 'WU package names: '
$links|Select-Object -ExpandProperty FileName|Select-Object -First 35|ForEach-Object {Write-Host "  $_"}
foreach($item in $items) {
  # Windows Update filenames append a GUID file identifier after the package moniker.
  # Match the exact pinned package identity followed by one GUID; trust only bytes matching our pinned SHA256.
  $ext=[IO.Path]::GetExtension($item.Filename)
  $match=@($links | Where-Object {$_.FileName -like ($item.Moniker + '_*' + $ext)})
  if($match.Count -lt 1){throw "Requested Store package version not returned by Microsoft WU: $($item.Filename)"}
  $dest=Join-Path $storeFolder $item.Filename
  $good=$false
  foreach($link in $match) {
    try{$u=[uri][string]$link.Url}catch{continue}
    # Microsoft WU sometimes returns an HTTP Microsoft CDN URL. Authenticity is established below by
    # the pinned SHA-256 of the complete file and a VALID Microsoft package signature.
    if($u.Scheme -notin @('https','http') -or
       -not ($u.Host -eq 'dl.delivery.mp.microsoft.com' -or $u.Host.EndsWith('.dl.delivery.mp.microsoft.com') -or $u.Host -eq 'delivery.mp.microsoft.com' -or $u.Host.EndsWith('.delivery.mp.microsoft.com'))) {
      Write-Warning "Rejected unapproved package download host $($u.Host)"
      continue
    }
    try {
      Write-Host "Downloading exact Microsoft Store file $($item.Filename)"
      $downloadUri=$u.AbsoluteUri
      if($u.Scheme -eq 'http') { $httpsUrl=[UriBuilder]::new($u); $httpsUrl.Scheme='https'; $httpsUrl.Port=-1; $downloadUri=$httpsUrl.Uri.AbsoluteUri }
      Invoke-WebRequest -UseBasicParsing -Uri $downloadUri -OutFile $dest -ErrorAction Stop
      $actual=Get-Item -LiteralPath $dest
      $actualHash=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
      if($actual.Length -ne $item.Length -or $actualHash -ine $item.Hash) {
        Write-Warning "Rejected WU file bytes: expected $($item.Length) / $($item.Hash), received $($actual.Length) / $actualHash"
        continue
      }
      $sig=Get-AuthenticodeSignature -LiteralPath $dest
      if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
        Write-Warning "Rejected untrusted Microsoft package signature: $($sig.Status)"
        continue
      }
      $good=$true;break
    } catch {
      Write-Warning "Microsoft CDN attempt failed for $($item.Filename): $($_.Exception.Message)"
    }
  }
  if(-not $good){throw "Cannot obtain byte-verified signed package via WU: $($item.Filename)"}
}
Copy-Item -LiteralPath '.github/build/Install-Store.ps1' -Destination (Join-Path $storeFolder 'Install-Store.ps1')
@'
WINDOWS SERVER 2022 x64 - MICROSOFT STORE CORE
Official Microsoft Store 22610.1401.10.0, x64 VCLibs and UI.Xaml.
Extract this archive. In an elevated Windows PowerShell terminal within that folder:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-Store.ps1
The installer verifies hardcoded SHA-256 hashes and Microsoft signatures.
This is the minimal Store-only package (no StorePurchaseApp, Xbox or AppInstaller).
The Store installer does not patch InstallService.dll.
Unofficial community test kit; test on isolated VM first.
'@|Set-Content -LiteralPath (Join-Path $storeFolder 'README.txt') -Encoding UTF8

# Confirm this exact executable is the newly rebuilt Win64 patcher (not x86).
if(-not (Test-Path -LiteralPath $PatcherExe -PathType Leaf)){throw 'Compiled patcher absent'}
$exeBytes=[IO.File]::ReadAllBytes($PatcherExe)
$pe=[BitConverter]::ToInt32($exeBytes,0x3c)
if($pe -lt 64 -or [BitConverter]::ToUInt16($exeBytes,$pe+4) -ne 0x8664){throw 'Compiled EXE is not AMD64'}
$help=& $PatcherExe '-?'
if($LASTEXITCODE -ne 0 -or ($help -join ' ') -notmatch 'Usage'){throw 'Patcher -? is not working'}
Copy-Item -LiteralPath $PatcherExe -Destination (Join-Path $patcherFolder 'InstallServicePatcher.exe')
@'
INSTALLSERVICEPATCHER - WINDOWS X64
View usage: InstallServicePatcher.exe -?
Patch writable offline copy: InstallServicePatcher.exe "D:\TEST\InstallService.dll"
Restore backup: InstallServicePatcher.exe "D:\TEST\InstallService.dll" --restore
Creates <DLL>.original.bak; never modifies System32 automatically.
Verified versions: 20348.3692, 20348.5756, 20348.5866.
Modifying a Microsoft-signed DLL invalidates the original signature.
After separately deploying the patched file on an isolated test VM, restart.
'@|Set-Content -LiteralPath (Join-Path $patcherFolder 'README.txt') -Encoding UTF8

$storeZip=Join-Path $OutDirectory 'MicrosoftStore_Server2022_x64_22610.1401.10.0.zip'
$patcherZip=Join-Path $OutDirectory 'InstallServicePatcher_x64.zip'
Compress-Archive -Path (Join-Path $storeFolder '*') -DestinationPath $storeZip -Force
Compress-Archive -Path (Join-Path $patcherFolder '*') -DestinationPath $patcherZip -Force
foreach($file in @($storeZip,$patcherZip)){
  Write-Host ("RELEASE_ASSET {0} Size={1} SHA256={2}" -f ([IO.Path]::GetFileName($file)),(Get-Item $file).Length,(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash)
}
