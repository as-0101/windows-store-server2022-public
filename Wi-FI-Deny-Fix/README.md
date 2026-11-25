# Wi-FI-Deny-Fix — optional diagnostics

**Status: research only. No validated universal fix is distributed in this release.**

This optional section concerns Microsoft Store network failures on some Windows Server 2022 installations where Windows Filtering Platform (WFP), Wi-Fi capability policy or `MPSSVC_QUARANTINE` may be involved.

**Do not apply arbitrary registry, firewall or WFP modifications** without identifying the blocked process, filter, time and rule owner. A successful InstallService patch does not imply any Wi-Fi modification is necessary.

If Store opens, downloads apps and installs them normally, **skip this section entirely**.

Before reporting a suspected Wi-Fi-deny issue, capture the exact Store error code, whether the host uses Ethernet or Wi-Fi, and an appropriate diagnostic trace with credentials and private network information removed.

---

## Русский

Необязательный раздел для диагностики сетевой блокировки Microsoft Store на Windows Server 2022. **Готового универсального Wi-Fi фикса пока нет.** Нельзя отключать системные сетевые фильтры наугад.

Если Store скачивает и устанавливает приложения, эта папка вам не нужна.