<p align="center">
  <img src="assets/brand/crocell-glyph.svg" width="160" alt="Crocell">
</p>

<h1 align="center">Crocell</h1>

<p align="center">
  VPN-клиент, который не нужно сначала изучать.<br>
  Linux · Windows · macOS · Android<br>
  VLESS Reality · XHTTP · VMess · Trojan · Shadowsocks · Hysteria2 · TUIC · WireGuard · AmneziaWG
</p>

<p align="center">
  <a href="README.md">English</a> &nbsp;|&nbsp; <b>Русский</b>
</p>

<p align="center">
  <a href="https://github.com/WiselessGroup/Crocell/releases/latest"><img alt="Последний релиз" src="https://img.shields.io/github/v/release/WiselessGroup/Crocell?label=release&color=E9524E"></a>
  <a href="https://github.com/WiselessGroup/Crocell/releases"><img alt="Скачивания" src="https://img.shields.io/github/downloads/WiselessGroup/Crocell/total?color=D4572A"></a>
  <a href="https://github.com/WiselessGroup/Crocell/actions/workflows/build.yml"><img alt="Сборка" src="https://img.shields.io/github/actions/workflow/status/WiselessGroup/Crocell/build.yml?branch=master"></a>
  <a href="https://github.com/WiselessGroup/Crocell/commits/master"><img alt="Последний коммит" src="https://img.shields.io/github/last-commit/WiselessGroup/Crocell?color=860111"></a>
  <a href="https://github.com/WiselessGroup/Crocell/stargazers"><img alt="Звёзды" src="https://img.shields.io/github/stars/WiselessGroup/Crocell?style=flat&color=E9524E"></a>
  <a href="LICENSE"><img alt="Лицензия" src="https://img.shields.io/github/license/WiselessGroup/Crocell?color=555"></a>
</p>

<p align="center">
  <img src="assets/screenshots/home-dark.png" width="820" alt="Crocell подключён, рядом список нод">
</p>

Вставил ссылку на подписку, выбрал ноду, нажал кнопку. Это весь первый экран. Без простыни переключателей и без «пинг 5000», который никому ничего не говорит.

Внутри [mihomo](https://github.com/MetaCubeX/mihomo), так что все современные протоколы на месте. Сверху то, чего мне не хватало в других клиентах: видно, где у ноды на самом деле выход; Crocell проверяет, что трафик правда идёт через VPN, и говорит, когда перестал; сайт или программу можно пустить мимо туннеля без правки YAML.

Crocell бесплатный и с открытым кодом, без аккаунтов, рекламы и телеметрии. Это только клиент: подписку даёт ваш провайдер, а можно подключить и свой сервер.

## Скачать

| Система | Файл |
|---|---|
| Linux, x86_64 | [Crocell-x86_64.AppImage](https://github.com/WiselessGroup/Crocell/releases/latest/download/Crocell-x86_64.AppImage) |
| Windows 10 / 11, x64 | [Crocell-x86_64-Setup.exe](https://github.com/WiselessGroup/Crocell/releases/latest/download/Crocell-x86_64-Setup.exe) |
| macOS, Apple silicon | [Crocell-arm64.dmg](https://github.com/WiselessGroup/Crocell/releases/latest/download/Crocell-arm64.dmg) |
| Android 7+ | [Crocell.apk](https://github.com/WiselessGroup/Crocell/releases/latest/download/Crocell.apk) |

Когда выходит новая версия, Crocell сообщает об этом после подключения, а по клику на уведомление показывает, как обновиться именно на вашей системе. Язык интерфейса, русский или английский, берётся из системы.

### Первый запуск

На компьютере VPN держит маленькая системная служба: закрыли или обновили окно, а соединение не моргнуло. Права администратора ей нужны один раз:

- **Linux.** Crocell покажет команду установки и кнопку «скопировать». Если AppImage живёт в [Gear Lever](https://flathub.org/apps/it.mijorus.gearlever), команда такая: `sudo ~/AppImages/crocell.appimage crocelld install`. Обновления Gear Lever подтягивает сам.
- **Windows.** Службу ставит установщик. Сборка пока без цифровой подписи, поэтому SmartScreen предупредит: «Подробнее», затем «Выполнить в любом случае».
- **macOS.** Перетащите Crocell в «Программы». Приложение не нотаризовано, и первый запуск macOS заблокирует: разрешите его в «Системные настройки» → «Конфиденциальность и безопасность» → «Всё равно открыть». Потом нажмите в Crocell «Установить службу» и введите пароль.
- **Android.** Разрешите браузеру установить APK, а потом разрешите VPN, когда Crocell спросит. Больше ничего ставить не надо.

## Что умеет

- Читает подписки любого вида: ссылки `vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`, `tuic://`, base64 от них, Clash/mihomo YAML с `proxy-providers`. Формат определяет сам, название, трафик и срок берёт из того, что присылает провайдер.
- Принимает WireGuard и AmneziaWG: вставьте конфиг, ссылку `awg://` или ключ `vpn://` из AmneziaVPN.
- Работает с VLESS Reality и Vision, XHTTP, Hysteria2 с obfs и всем остальным, что умеет mihomo.
- Показывает ноду флагом и городом выхода после проверки, а не цифрой задержки. Если в названии Нидерланды, а выход в Германии, вы это увидите. Ноды, не прошедшие проверку, можно спрятать одним переключателем.
- Подключается системным прокси (без прав администратора, для программ, которые его слушаются) или туннелем TUN для всей системы. На Android тот же выбор означает весь телефон через VPN или локальный прокси для приложений, где вы его указали.
- Раскладывает трафик по трём спискам: через VPN, напрямую, блокировать. Правило может быть сайтом, маской, подсетью, набором geosite/geoip из баз [runetfreedom](https://github.com/runetfreedom/russia-v2ray-rules-dat) (или своих), программой или приложением на Android. Списки из конфигов v2ray вставляются как есть, с `domain:` и `full:`. Точное правило важнее общего.
- Проверяет соединение сразу после подключения и потом раз в пару минут, а если трафик перестал проходить, присылает уведомление.
- Сам подхватывает новые настройки: поменяли правило при включённом VPN, и туннель тихо переподключился.
- Включается и выключается, не открывая окна: плитка в шторке Android и переключатель в быстрых настройках GNOME (ставится из настроек кнопкой «Добавить в быстрые настройки GNOME»).
- Даёт выбрать картинку на кнопке, а на Windows и Android ещё и иконку приложения с фоном. На macOS выбор из двух, и значок сам следует за светлой или тёмной темой.
- Копирует свои логи одной кнопкой, без ссылок на подписки: если что-то сломалось и хочется [рассказать нам](https://github.com/WiselessGroup/Crocell/issues/new/choose).
- Хранит подписки и настройки зашифрованными в AES-256-GCM. На Linux ключ запечатан через `systemd-creds` (с TPM, если он есть), на Android лежит в Keystore. Скопированный файл состояния на другой машине бесполезен.

<p align="center">
  <img src="assets/screenshots/rules-dark.png" width="820" alt="Правила маршрутизации: три списка, сгруппированные по типу">
</p>

## Вопросы

**Это VPN-сервис?** Нет. У Crocell нет серверов, и он ничего не продаёт. Нужна подписка или конфиг от провайдера либо свой сервер.

**Прочитает ли он подписку моего провайдера?** Если это ссылки V2Ray/Xray, base64 от них или Clash/mihomo YAML, должен. Если не прочитал, [напишите нам](https://github.com/WiselessGroup/Crocell/issues/new?template=bug_report.yml), только саму ссылку не публикуйте: это ключ от вашего VPN.

**Куда приложение ходит само?** Вот весь список:

- по ссылкам на подписки, которые вы добавили;
- на страницу trace у Cloudflare, через ноду, чтобы узнать, где у неё выход;
- к DNS-серверам из настроек, через туннель (1.1.1.1 и 8.8.8.8, если не меняли);
- на GitHub, за проверкой обновлений и базами geosite/geoip.

## Как устроено

```
app/              клиент на Flutter: интерфейс, никакой логики протоколов
core/             ядро на Go поверх mihomo: подписки, проверки, туннель
  cmd/crocelld    служба, которая держит туннель на компьютере
  cmd/crocell     CLI для разработки и отладки
  mobile          ядро как библиотека для Android (gomobile)
  third_party/    mihomo с нашими исправлениями, подробности в его CROCELL.md
proto/            контракт клиента и ядра
```

На компьютере клиент говорит с `crocelld` через локальный сокет (на Windows через loopback с токеном: там у Dart нет unix-сокетов). На Android то же ядро работает внутри приложения, а интерфейс для него строит `VpnService`.

## Сборка из исходников

Нужны Go 1.26+ и Flutter 3.47+.

```bash
cd core
make test
go run ./cmd/crocell nodes 'https://example.com/sub/…'
go run ./cmd/crocell up 'https://example.com/sub/…' --node 'nlWISELESS'
```

`crocell up` поднимает mixed-прокси на `127.0.0.1:7890` через выбранную ноду: удобно ковырять ядро без приложения. С `-sysproxy` он пропишет системный прокси, а после `make build` команда `sudo bin/crocell up … -tun` пустит через ноду всю систему.

Запустить приложение со службой на своей машине:

```bash
cd core && make install-daemon     # Linux: ставит и запускает crocelld
cd ../app && flutter run -d linux
```

`CROCELL_SOCKET=/путь/к/crocelld.sock` направит клиент на службу, запущенную руками. После правок в `proto/` выполните `make proto` в `core/` (нужен `dart pub global activate protoc_plugin`).

Пакеты собирают скрипты в `scripts/`: `build-appimage.sh`, `build-windows.sh`, `build-macos.sh` и `build-android.sh`, каждый принимает версию.

## Как помочь

Больше всего помогают отчёты об ошибках, особенно по подпискам и сетям, которые я сам проверить не могу. Настройка окружения и правила описаны в [CONTRIBUTING.ru.md](CONTRIBUTING.ru.md), инструкции для кодинг-агентов в [AGENTS.md](AGENTS.md), а про уязвимости написано в [SECURITY.md](SECURITY.md).

Если Crocell избавил вас от правки YAML, поставьте звезду: так его проще найти другим.

## Лицензия

[GPL-3.0](LICENSE).
