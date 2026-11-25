# Диагностика неполадок / Troubleshooting

[← Главная](../README.md) · [FAQ](FAQ.md) · [Создать Issue](https://github.com/as-0101/windows-store-server2022-public/issues/new/choose)

## Определите этап сбоя

| Симптом | Что проверять | Не делайте |
| --- | --- | --- |
| Store не запускается | Регистрация AppX, зависимости, журнал AppXDeploymentServer | Не изменяйте InstallService наугад |
| Store открывается, но «Получить» недоступно | Доступность конкретного продукта для Windows.Server, HRESULT, лицензирование | Не считайте сетевой доступ доказательством совместимости |
| Загрузка не начинается или обрывается | Сетевые коды ошибок, DNS, TLS, BITS/DoSvc, WFP только при наличии фактов | Не отключайте брандмауэр или системные фильтры целиком |
| Патчер отклоняет DLL | Версия, архитектура, хеш оригинала, сообщение утилиты | Не отключайте проверки и не патчите неизвестную ревизию вручную |
| После обновления Windows поведение изменилось | Текущая версия компонента, журнал обновлений, прежняя резервная копия | Не подменяйте новые системные DLL файлами от других сборок |

## Минимальные сведения для обращения

1. Редакция и полная сборка Windows Server 2022 (включая UBR); тестовая VM или рабочий сервер.
2. Версия `InstallService.dll` и статус оригинальной подписи, **без передачи системного файла в публичный Issue**.
3. Какой архив и какой релиз использованы.
4. Какая операция выполнялась: запуск Store / нажатие «Получить» / загрузка / установка / «Открыть».
5. Название приложения, точный HRESULT или текст ошибки и время события.
6. Есть ли подключение через Wi-Fi или Ethernet; выполняется ли проверка на чистой VM.
7. Если есть журналы — только относящийся к сбою фрагмент после удаления персональных сведений.

## Команды только для чтения

Выполняйте по одной команде в Windows PowerShell, а не все сразу.

**Сборка ОС и UBR:**

`Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Select-Object ProductName,CurrentBuild,UBR`

**Проверка версии и хеша DLL (не изменяет файл):**

`Get-Item 'C:\Windows\System32\InstallService.dll' | Select-Object FullName,Length,@{N='FileVersion';E={$_.VersionInfo.FileVersion}}`

**Проверка подписи оригинала:**

`Get-AuthenticodeSignature 'C:\Windows\System32\InstallService.dll' | Select-Object Status,SignerCertificate`

**Проверка регистрации Store:**

`Get-AppxPackage -AllUsers Microsoft.WindowsStore | Select-Object Name,Version,PackageFullName`

Не выкладывайте необработанные полные системные журналы. При отсутствии приложения в каталоге или при ошибке доступности товара сначала проверьте, заявлена ли издателем поддержка Windows Server.

## English

Identify the failing stage before troubleshooting: Store registration, product eligibility, network transfer, deployment or launch. Report the Windows build/UBR, component revision, app, action, exact error and sanitized evidence. Never publish credentials, full private logs or protected Windows binaries. Do not disable security filters or integrity checks to make tests pass.
