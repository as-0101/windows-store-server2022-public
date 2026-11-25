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
$sfsBase='https://storeapps.api.cdp.microsoft.com/api/v2/contents/storeapps/namespaces/default/names'
$product='64293252-5926-453c-9494-2d4021f1c78d'
$latest=Invoke-RestMethod -Uri "$sfsBase/$product/versions/latest?action=select" -Method Post -ContentType 'application/json' -Body '{"TargetingAttributes":{}}'
if(-not $latest.ContentId.Version) {throw 'Microsoft SFS did not return a current Store content version'}
$versions=@([pscustomobject]@{Name=$latest.ContentId.Name;Version=$latest.ContentId.Version})
$versions+=@($latest.Prerequisites|Where-Object {$_.Name -and $_.Version}|ForEach-Object {[pscustomobject]@{Name=$_.Name;Version=$_.Version}})
$files=@()
foreach($v in $versions){
  $url="$sfsBase/$($v.Name)/versions/$($v.Version)/files?action=GenerateDownloadInfo"
  $files+=@(Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json')
}
foreach($item in $items){
  $matching=@($files|Where-Object {$_.FileMoniker -eq $item.Moniker})
  if($matching.Count -ne 1){throw "SFS file not found uniquely: $($item.Moniker)"}
  $meta=$matching[0]
  # SFS may return URL candidates and hash values as arrays or provider-specific objects.
  # Prefer an allowed Microsoft CDN candidate; never use arbitrary URLs.
  $urls=@(foreach($candidate in @($meta.Url)){
    if($candidate -is [string]){$candidate}
    elseif($null -ne $candidate -and $candidate.Url){[string]$candidate.Url}
  })
  $urlString=$null
  foreach($candidateUrl in $urls){
    if([string]::IsNullOrWhiteSpace($candidateUrl)){continue}
    try{$tryUri=[uri]$candidateUrl}catch{continue}
    if($tryUri.Scheme -in @('https','http') -and ($tryUri.Host -eq 'dl.delivery.mp.microsoft.com' -or $tryUri.Host.EndsWith('.dl.delivery.mp.microsoft.com'))){
      $urlString=$candidateUrl
      break
    }
  }
  if(-not $urlString){throw "No approved Microsoft CDN URL supplied for $($item.Moniker)"}
  # The pinned SHA256 below is an independently recorded hash of the exact, original,
  # signed Microsoft package. SFS field representations have varied between runs.
  # Parse the optional SFS SHA256 as hex or Base64 where possible; always enforce
  # the pinned hash on the downloaded bytes regardless of metadata shape.
  $sfsCandidate=$meta.Hashes.Sha256
  if($sfsCandidate -is [string] -and -not [string]::IsNullOrWhiteSpace($sfsCandidate)){
    $candidateHash=$null
    if($sfsCandidate -match '^[0-9a-fA-F]{64}$'){$candidateHash=$sfsCandidate}
    elseif($sfsCandidate -match '^[A-Za-z0-9+/]{43}=$'){
      $candidateHash=[BitConverter]::ToString([Convert]::FromBase64String($sfsCandidate)).Replace('-','')
    }
    if($candidateHash -and $candidateHash -ine $item.Hash){throw "SFS SHA256 differs from pinned Microsoft package hash"}
  }
  # Source metadata sometimes returns multi-valued size fields; verify actual downloaded byte length below.
  $dest=Join-Path $storeFolder $item.Filename
  Write-Host "Downloading signed Microsoft component $($item.Filename)"
  $downloaded=$false
  for($attempt=1;$attempt -le 3;$attempt++){
    try{
      Invoke-WebRequest -UseBasicParsing -Uri $urlString -OutFile $dest -ErrorAction Stop
      $downloaded=$true;break
    }catch{
      if($attempt -eq 3){throw}
      Start-Sleep -Seconds (4*$attempt)
    }
  }
  if(-not $downloaded){throw "Cannot download $($item.Moniker)"}
  $file=Get-Item -LiteralPath $dest
  if($file.Length -ne $item.Length){throw "Size mismatch for $($item.Filename)"}
  if((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ine $item.Hash){throw "SHA-256 mismatch for $($item.Filename)"}
  $sig=Get-AuthenticodeSignature -LiteralPath $dest
  if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Microsoft Corporation'){
    throw "Package signature invalid for $($item.Filename): $($sig.Status)"
  }
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
