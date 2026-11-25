# Безопасность / Security policy

Этот проект **экспериментальный**, не связан с Microsoft или OpenAI и не является поддерживаемым Microsoft решением для Windows Server 2022.

## Поддерживаемая область

Исследуются Windows Server 2022 x64 (семейство ОС 20348), установка Microsoft Store и ограниченный набор известных ревизий `InstallService.dll`. Не заявлена поддержка новых поколений Windows Server или произвольных DLL.

Модификация Microsoft DLL нарушает её исходную цифровую подпись и может вызвать отказ Windows Code Integrity. Успешный тест на одной VM не означает безопасность для production. Выполняйте проверку в изолированной VM, сохраняйте исходники/резервные копии и способ восстановления.

## Сообщить о проблеме

- **Обычная ошибка:** создайте [Issue](https://github.com/as-0101/windows-store-server2022-public/issues/new/choose) с очищенными диагностическими данными.
- **Потенциальная уязвимость:** не размещайте рабочий эксплойт, секреты, приватные ссылки, токены или неотредактированные логи в публичном Issue. Используйте приватный канал GitHub Security Advisories / Report a vulnerability, **если он доступен в настройках репозитория**; в противном случае сначала запросите у владельца безопасный канал передачи без раскрытия технических деталей.

Нельзя обещать конкретный срок реакции или выпуск исправления. Вопросы безопасности и воспроизводимости важнее ускорения релиза.

## English

Experimental, unofficial software; no security or compatibility guarantee. Modifying a Microsoft DLL invalidates its original signature. Test on isolated VMs and keep recovery backups. Report routine defects through sanitized Issues. Do not disclose vulnerabilities, exploits, tokens or sensitive logs in public tickets; use private GitHub vulnerability reporting if enabled.
