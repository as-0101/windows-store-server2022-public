# Microsoft Store on Windows Server 2022

**Microsoft Store deployment kit and offline InstallService compatibility patcher for Windows Server 2022 x64 (build 20348).**

[**Download releases**](https://github.com/as-0101/windows-store-server2022-public/releases) · [Installation guide](#installation--установка) · [Optional Wi-Fi diagnostics](Wi-FI-Deny-Fix/README.md)

> **Community experiment · Unofficial · Not affiliated with Microsoft.** Test in an isolated VM before using on important systems. Do not disable Windows security or licensing checks.

## Downloads / Загрузки

| Package | Contents | Purpose |
|---|---|---|
| **MicrosoftStore_Server2022_x64_22610.1401.10.0.zip** | Microsoft Store 22610.1401.10.0, x64 VCLibs 14.0, UI.Xaml 2.8, `Install-Store.ps1` | Offline Store registration |
| **InstallServicePatcher_x64.zip** | `InstallServicePatcher.exe`, usage guide | Offline patch of a separately stored `InstallService.dll`, with backup and rollback |
| **[Wi-FI-Deny-Fix](Wi-FI-Deny-Fix/README.md)** | Optional diagnostic notes | Investigating Wi-Fi/WFP-specific blocked connections; no tested universal fix yet |

Archives are delivered as **GitHub Release assets**, not GitHub Actions artifacts that expire. SHA-256 checksums are published with the release.

## Validated revisions / Проверенные ревизии

| Windows Server component | Offline patcher | Microsoft Store result |
|---|---|---|
| InstallService **20348.3692** | Patched with extra `.eqplat` section | **Confirmed:** ChatGPT downloaded, installed and opened after VM restart |
| InstallService **20348.5756** | Reproduces previously user-tested DLL byte-for-byte | Previously user-confirmed working on Server 2022 |
| InstallService **20348.5866** | Patched via existing code padding | **Confirmed:** Store displayed WhatsApp as installed/openable |

The host OS build and the DLL's file version can differ. Other revisions are **not guaranteed**. Unsupported layouts must be rejected rather than blindly modified.

## Installation / Установка

**1. Extract** the Store ZIP into a dedicated directory on an x64 Windows Server 2022 test VM. Confirm the included Microsoft packages have valid signatures.

**2. Run** the included script using an elevated Windows PowerShell session:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-Store.ps1"
```

**3. Patch a detached DLL** *only in a writable test directory*, not directly in System32. Run the x64 patcher:

```powershell
.\InstallServicePatcher.exe -?
```

```powershell
.\InstallServicePatcher.exe "D:\TEST\InstallService.dll"
```

The program creates `InstallService.dll.original.bak`. It does **not** change file permissions or install the modified binary into Windows. Any deployment of a modified system file requires a separate, controlled process with a recovery plan.

**4. Restart the test VM** after completing the relevant test deployment, and verify that a previously absent, free application can be downloaded, installed and launched through Microsoft Store. In the 20348.3692 experiment, installation progressed only after reboot.

**Rollback:**

```powershell
.\InstallServicePatcher.exe "D:\TEST\InstallService.dll" --restore
```

The original backup is retained.

## Scope, limitations and integrity

- **Windows Server 2022 / x64 only.** No claim of support for every system revision.
- Patched Microsoft DLLs **lose their original Authenticode signature integrity** and may be rejected by Windows code-integrity protections. The program does not bypass these protections.
- The Store archive includes the **core Store package and two dependencies only**. It is *not* the previous full distribution containing StorePurchaseApp, XboxIdentityProvider and DesktopAppInstaller.
- No firewall, WFP, Wi-Fi policy, Microsoft account or licensing changes are made by the included Store installation script.
- Microsoft Store files are Microsoft's property. Redistribution and use are subject to Microsoft's applicable license terms.
- **Never use third-party DLL files or patching tools on production infrastructure without independently verifying provenance, recovery and security implications.**

---

## Русское краткое описание

Это экспериментальный комплект для Windows Server 2022 x64: установка Microsoft Store и отдельный патчер `InstallService.dll`. Патчер обрабатывает DLL в указанном каталоге, создаёт резервную копию и поддерживает восстановление через `--restore`. Справка: `-?`.

Проверены три ревизии компонента. На тестовой VM после перезагрузки приложение ChatGPT установилось из Store и запустилось. **Для других ревизий совместимость не гарантируется.**

**Wi-Fi-Deny-Fix** — отдельный необязательный раздел, а не обязательная часть установки.