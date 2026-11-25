<div align="center">

# Microsoft Store для Windows Server 2022

**Microsoft Store + InstallServicePatcher · Windows Server 2022 x64**

Набор для установки Microsoft Store и экспериментального восстановления совместимости установки приложений.

**[⬇️ Выпуски дистрибутива](https://github.com/as-0101/windows-store-server2022-public/releases)** · [Инструкция](#как-установить) · [FAQ](docs/FAQ.md) · [Диагностика](docs/TROUBLESHOOTING.md) · [English](#english)

[![Platform](https://img.shields.io/badge/Platform-Windows%20Server%202022-0078D4)](https://learn.microsoft.com/en-us/windows-server/get-started/whats-new-in-windows-server-2022)
![Revisions tested](https://img.shields.io/badge/InstallService-3%20revisions%20tested-008080)
![Status](https://img.shields.io/badge/Status-Experimental-orange)

</div>

> [!IMPORTANT]
> **Неофициальный проект, не связанный с Microsoft или OpenAI.** Проверяйте результат на изолированной VM. Изменение системной DLL нарушает её исходную цифровую подпись. Работа на всех ревизиях не гарантируется.

## Загрузки

| Компонент | Что внутри | Назначение |
|---|---|---|
| **[Microsoft Store](https://github.com/as-0101/windows-store-server2022-public/releases)** | Store 22610.1401.10.0, VCLibs x64, UI.Xaml 2.8, `Install-Store.ps1` | Установка и регистрация Store |
| **[InstallServicePatcher](https://github.com/as-0101/windows-store-server2022-public/releases)** | Windows x64 EXE, справка, backup, rollback | Модификация отдельной копии `InstallService.dll` |
| **[Wi-FI-Deny-Fix](Wi-FI-Deny-Fix/README.md)** | Необязательная диагностика сети | Экспериментальная ветка, готового универсального Wi-Fi фикса пока нет |

**Статус:** публичный GitHub Release ещё не опубликован: Microsoft CDN сейчас выдаёт содержимое, не совпадающее с ранее проверенным MSIXBundle. Оба проверенных архива уже подготовлены отдельно; при публикации должны появиться в GitHub Releases. Файлы исходников и временные GitHub Actions artifacts не являются установочными архивами.

> [!NOTE]
> Если в [Releases](https://github.com/as-0101/windows-store-server2022-public/releases) нет **опубликованного** выпуска с обоими ZIP-файлами, постоянная загрузка пока не готова. Не путайте черновики релизов и временные артефакты Actions с опубликованным дистрибутивом.

## Помощь посетителям

**[Частые вопросы](docs/FAQ.md)** · **[Диагностика ошибок](docs/TROUBLESHOOTING.md)** · **[Проверка загрузок и подписей](docs/VERIFY_DOWNLOADS.md)**

Для сообщений об ошибках используйте [GitHub Issues](https://github.com/as-0101/windows-store-server2022-public/issues/new/choose), предварительно удалив из логов личную информацию. Для улучшений проекта доступны [правила участия](CONTRIBUTING.md) и [шаблон Pull Request](.github/pull_request_template.md). О потенциальных уязвимостях см. [SECURITY.md](SECURITY.md).

## Как установить

**1 — Store.** Распакуйте архив `MicrosoftStore_Server2022_x64_22610.1401.10.0.zip`. Запустите из распакованного каталога в Windows PowerShell от администратора:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-Store.ps1"

Скрипт проверяет SHA-256 и подписи Microsoft, затем регистрирует Store. **Не меняет** системные DLL, WFP, брандмауэр, настройки аккаунта или лицензирования.

**2 — Патчер.** Распакуйте архив `InstallServicePatcher_x64.zip`. Показать доступные команды:

    .\InstallServicePatcher.exe -?

Модифицировать **отдельную оригинальную копию DLL в каталоге с доступом на запись**:

    .\InstallServicePatcher.exe "D:\TEST\InstallService.dll"

Патчер создаёт `InstallService.dll.original.bak`, проверяет структуру кода и отказывается менять неизвестные ревизии. Он **не подменяет DLL в System32** и не изменяет разрешения Windows.

Восстановить оригинальную копию:

    .\InstallServicePatcher.exe "D:\TEST\InstallService.dll" --restore

**3 — Проверка.** После контролируемого тестового развёртывания и перезагрузки VM убедитесь, что Store скачивает, устанавливает и открывает ранее отсутствовавшее бесплатное приложение. Для испытанной версии 20348.3692 перезагрузка оказалась необходимой.

## Проверенные версии

| Версия InstallService.dll | Имеющиеся свидетельства |
|---|---|
| **20348.3692** | После патча и перезагрузки VM ChatGPT скачан из Store, установлен и запущен |
| **20348.5756** | Создана побайтно идентичная ранее испытанной рабочая модификация |
| **20348.5866** | Патч выполнен, пользователь подтвердил работу Store (WhatsApp отображается с кнопкой «Открыть») |

> [!NOTE]
> Версия компонента и сборка ОС могут различаться. На испытанной VM ОС была `20348.4893`, а файл `InstallService.dll` — `20348.3692`. Сборки вне этого списка не гарантируются.

## Ограничения

- **Windows Server 2022 x64**, семейство сборок `20348`. Для других поколений Windows Server поддержка не заявлена.
- Модификация Microsoft DLL нарушает исходную подпись Authenticode и может быть отклонена Windows Code Integrity. Патчер эту защиту не отключает.
- Store ZIP содержит **основной Store и две зависимости** — не полный комплект с XboxIdentityProvider, StorePurchaseApp и DesktopAppInstaller.
- Используйте резервные копии, тестовую VM и план восстановления. Не применяйте к рабочим серверам без самостоятельной проверки.
- Microsoft Store и его подписанные пакеты принадлежат Microsoft; распространение и использование подчиняются условиям Microsoft.
- **Wi-FI-Deny-Fix** не нужен, если Store нормально скачивает и устанавливает приложения.

---

## English

An **unofficial, experimental** Microsoft Store deployment kit and standalone InstallService compatibility patcher for **Windows Server 2022 x64 (build family 20348)**.

Download the two ZIP files from [GitHub Releases](https://github.com/as-0101/windows-store-server2022-public/releases). The Store archive contains official Microsoft-signed Store 22610.1401.10.0 and minimal x64 dependencies. The patcher provides `-?` help, `.original.bak` backup and `--restore` rollback for a **detached, writable DLL copy**.

Tested component revisions: **20348.3692, 20348.5756, 20348.5866**. On the 20348.3692 test VM, ChatGPT was downloaded, installed and launched after reboot. Other revisions are **not guaranteed**. Patching invalidates the DLL's original digital signature; test only in isolated environments.

Optional [Wi-FI-Deny-Fix](Wi-FI-Deny-Fix/README.md) documents network diagnostics; it is not a verified one-click repair.

---

<sub>Community project · Not affiliated with or endorsed by Microsoft or OpenAI.</sub>
