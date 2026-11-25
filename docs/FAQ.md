# Частые вопросы / FAQ

[← Главная](../README.md) · [Диагностика](TROUBLESHOOTING.md) · [Проверка загрузок](VERIFY_DOWNLOADS.md)

### Что это за проект?

Неофициальный экспериментальный комплект для Windows Server 2022 x64 (семейство сборок 20348): установка Microsoft Store и отдельная утилита для исследования совместимости `InstallService.dll`. Проект не связан с Microsoft или OpenAI.

### Microsoft Store установлен. Почему «Получить» может не работать?

Установка интерфейса Store и разрешение скачать конкретное приложение — разные этапы. Результат зависит от доступности приложения для данной ОС, служб, лицензирования, сети и целостности Windows. Наличие Store не означает поддержку всех продуктов на Windows Server.

### Патчер обязателен для установки Store?

**Нет.** Дистрибутив Store регистрирует приложение отдельно. Патчер работает только с указанной ему отдельной копией `InstallService.dll`; системный DLL-файл самостоятельно не подменяет.

### На каких версиях есть результаты?

| Версия `InstallService.dll` | Имеющиеся свидетельства |
| --- | --- |
| 20348.3692 | На тестовой VM пользователь показал загрузку, установку и запуск ChatGPT из Store после перезагрузки |
| 20348.5756 | Offline-патч побайтно совпал с ранее проверенным пользователем рабочим образцом |
| 20348.5866 | Пользователь подтвердил установленный WhatsApp в Store с кнопкой «Открыть» |

**Это не гарантия** для каждой ревизии сборки 20348; версия компонента и сборка ОС могут отличаться. Полная воспроизводимость всех сценариев обновления и влияние на Code Integrity не подтверждены.

### Безопасно ли менять оригинальный Microsoft DLL?

Модификация нарушает исходную цифровую подпись и может конфликтовать с механизмами целостности Windows и будущими обновлениями. Проверяйте эксперименты на изолированной VM; не отключайте проверку подписи или лицензирования.

### Нужен ли Wi-FI-Deny-Fix?

Если Store нормально загружает приложения — нет. Это [отдельный необязательный раздел диагностики сети](../Wi-FI-Deny-Fix/README.md), не универсальный фикс.

### Где скачать?

На странице [GitHub Releases](https://github.com/as-0101/windows-store-server2022-public/releases). Если там нет опубликованного релиза с ZIP-файлами, стабильная точка скачивания ещё отсутствует. Временные GitHub Actions artifacts не следует путать с готовым релизом.

### Как сообщить об ошибке?

Прочитайте [диагностику](TROUBLESHOOTING.md), затем создайте [Issue](https://github.com/as-0101/windows-store-server2022-public/issues/new/choose). Не публикуйте ключи, токены, адреса, сведения об учётных записях или приватные журналы.

---

## English — quick FAQ

This is an unofficial, experimental Windows Server 2022 x64 project. Installing Store does not guarantee that a particular app is eligible for Windows Server. The patcher modifies a detached copy of InstallService.dll and invalidates its original signature. Test on isolated VMs, keep backups, and do not disable Windows integrity or licensing protections. Only published [Releases](https://github.com/as-0101/windows-store-server2022-public/releases) are release downloads; [Issues](https://github.com/as-0101/windows-store-server2022-public/issues/new/choose) are for sanitized problem reports.
