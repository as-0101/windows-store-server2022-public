# Store 22610.1401.10.0 – Windows Server 2022 x64. Offline install only.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$dir=$PSScriptRoot
$packages=@(
 @{File='Microsoft.VCLibs.140.00_14.0.33519.0_x64__8wekyb3d8bbwe.appx';Sha='9C17B521F9D690A1F504DA5108ED6EEC5669EB3A8FD1331EEF43E40D84E74283'},
 @{File='Microsoft.UI.Xaml.2.8_8.2501.31001.0_x64__8wekyb3d8bbwe.appx';Sha='2E7C2397D95F415FF97E26E3A63D52BE4C2E4BE3F885517E522B8E94E37B4FE2'},
 @{File='Microsoft.WindowsStore_22610.1401.10.0_neutral_~_8wekyb3d8bbwe.msixbundle';Sha='F6CD9691B2E7CF940537A8BFBDE5723F2F0B2DFE1BFC6BE812A0C1E3205CB6FA'}
)
$os=Get-CimInstance Win32_OperatingSystem
if($os.BuildNumber -ne '20348'){throw "Windows Server 2022 build 20348 required"}
if(-not [Environment]::Is64BitOperatingSystem){throw 'x64 required'}
foreach($p in $packages){
 $p.Path=Join-Path $dir $p.File
 if(-not (Test-Path -LiteralPath $p.Path -PathType Leaf)){throw "Package absent: $($p.File)"}
 if((Get-FileHash -LiteralPath $p.Path -Algorithm SHA256).Hash -ine $p.Sha){throw "Package SHA256 mismatch: $($p.File)"}
 $sig=Get-AuthenticodeSignature -LiteralPath $p.Path
 if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notlike '*Microsoft Corporation*'){throw "Invalid Microsoft package signature: $($p.File)"}
}
Add-AppxPackage -Path $packages[2].Path -DependencyPath @($packages[0].Path,$packages[1].Path) -ErrorAction Stop
$p=Get-AppxPackage -Name Microsoft.WindowsStore | Sort-Object Version -Descending | Select-Object -First 1
if(-not $p -or $p.Status -ne 'Ok'){throw 'Store registration not confirmed'}
Write-Host "Store registered: $($p.PackageFullName)" -ForegroundColor Green
Write-Host 'This does not change InstallService or network policies.' -ForegroundColor Yellow
