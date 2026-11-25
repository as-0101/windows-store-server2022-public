# Проверка загрузок / Verify downloads

[← Главная](../README.md) · [Releases](https://github.com/as-0101/windows-store-server2022-public/releases) · [Безопасность](../SECURITY.md)

## Что скачивать

Архивы расположены в двух местах:

- [Microsoft Store — релиз v1.0.0](https://github.com/as-0101/windows-store-server2022-public/releases/tag/v1.0.0).
- [InstallServicePatcher — папка компонента](https://github.com/as-0101/windows-store-server2022-public/tree/main/InstallServicePatcher).

Контрольные суммы сравнивайте с данными именно скачанного файла; содержимое опубликованного Store ZIP отдельно не проверено.

## Проверьте целостность

Скачивайте непосредственно из указанных разделов этого репозитория. Для каждого скачанного архива сравните SHA-256 с **контрольной суммой того же самого выпуска**, если она опубликована. Не используйте хеши другого запуска workflow: скачанные заново Microsoft-пакеты или перепаковка могут изменить архив.

Для ZIP с Store выполните в Windows PowerShell из каталога загрузок:

`Get-FileHash -Algorithm SHA256 -LiteralPath '.\MicrosoftStore_Server2022_x64_22610.1401.10.0.zip'`

Для ZIP с патчером:

`Get-FileHash -Algorithm SHA256 -LiteralPath '.\InstallServicePatcher-win-x64.zip'`

После распаковки Store проверьте цифровые подписи пакетов Microsoft (в каталоге с MSIX/MSIXBundle):

`Get-ChildItem -File -Include '*.msix','*.msixbundle','*.appx','*.appxbundle' -Recurse | Get-AuthenticodeSignature | Select-Object Path,Status,SignerCertificate`

Ожидаемый результат для подлинных, неизменённых подписанных пакетов — `Valid` и издатель Microsoft; наличие подписи само по себе не гарантирует совместимость или безопасность всей процедуры.

## Важное отличие

Исходные MSIX-пакеты Store подписаны Microsoft. **Патчер — не официальная утилита Microsoft, а модифицированный InstallService.dll не сохраняет исходную подпись Microsoft.** Не ослабляйте Windows Code Integrity или политику лицензирования для запуска эксперимента.

## English

Download from the published release or the component folder linked above. Verify each ZIP SHA-256 against checksums published for that exact release. Verify original Microsoft app package signatures; never assume that a modified InstallService.dll remains Microsoft-signed. Workflow artifacts are temporary build outputs, not permanent release assets.
