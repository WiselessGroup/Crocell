<p align="center">
  <img src="assets/brand/crocell-emblem.svg" width="220" alt="Crocell">
</p>

<h1 align="center">Crocell</h1>

<p align="center">
  Кросс-платформенный VPN-клиент, которым приятно пользоваться.<br>
  Linux · Windows · macOS · Android · iOS — позже
</p>

---

Вставил ссылку на подписку, выбрал ноду, подключился. Без простыни настроек на первом экране и без цифр, которые ничего не говорят обычному человеку.

## Что умеет

- **Подписки любых форматов.** Share-ссылки (`vless://`, `vmess://`, `trojan://`, `ss://`, `hysteria2://`, `tuic://`), base64 от них, Clash/Mihomo YAML вместе с `proxy-providers`. Формат определяется по содержимому, метаданные подписки (название, трафик, срок) читаются из заголовков и из тела.
- **Современные транспорты.** VLESS Reality + Vision, XHTTP, Hysteria2 с obfs и всё, что умеет [mihomo](https://github.com/MetaCubeX/mihomo).
- **Понятное качество нод.** Вместо «пинг 5000» по кнопке «Проверить»: где у ноды выход (страна и город) и работает ли она. Дальше — вход, доступность нужных сайтов _(в работе)_.
- **Два режима подключения.** Системный прокси для браузеров и приложений, которые его слушаются, и TUN, когда через VPN идёт вся система, включая программы, которые про прокси не знают или не дают его отключить.
- **Маршрутизация в три списка: через VPN, напрямую, блокировать.** Сайты (`wiseless.net` — только он, `*.wiseless.net` — поддомены, `+.wiseless.net` — всё вместе), IP и подсети, наборы `geosite:` и `geoip:` из баз [runetfreedom](https://github.com/runetfreedom/russia-v2ray-rules-dat) (или своих), запущенные программы и программы по пути. Точное правило важнее общего.
- **Проверка соединения.** После подключения и потом раз в пару минут Crocell проверяет, что интернет правда идёт через VPN, и присылает уведомление, если нет.
- **Данные зашифрованы.** Подписки и настройки лежат на диске в AES-256-GCM; на Linux ключ запечатан через `systemd-creds` (TPM или ключ хоста), так что скопированный файл бесполезен.

## Как устроено

```
app/          клиент на Flutter: интерфейс, никакой логики протоколов
core/         ядро на Go поверх mihomo: подписки, проверки, туннель
  cmd/crocelld  служба ядра: держит туннель, отдаёт API клиенту
  cmd/crocell   CLI для разработки и отладки
proto/        контракт клиента и ядра
assets/brand/ логотип и иконки
```

На десктопе туннель держит отдельный процесс ядра, окно только с ним разговаривает: закрыли, обновили или уронили окно — VPN не моргнёт. На телефонах ядро живёт внутри системного VPN-сервиса.

## Разработка

Нужны Go 1.26+ и Flutter 3.47+.

```bash
cd core
make test
go run ./cmd/crocell nodes 'https://example.com/sub/…'
go run ./cmd/crocell up 'https://example.com/sub/…' --node 'nlWISELESS'
```

`crocell up` поднимает mixed-прокси на `127.0.0.1:7890` через выбранную ноду: удобно проверять ядро без клиента и без прав. С `-sysproxy` он сам пропишет системный прокси и вернёт старые настройки при выходе, с `-tun` пустит через ноду всю систему:

```bash
make build    # с тегом with_gvisor: без него стек TUN mixed не поднимется
sudo bin/crocell up 'https://example.com/sub/…' -node 'nlWISELESS' -tun
```

Через `make setcap` можно обойтись без sudo, но тогда `resolvectl` попросит пароль у polkit: три раза при старте и раз при выходе. В приложении туннель держит служба, которая получает права один раз при установке. Не держите одновременно два TUN-клиента: их маршруты подерутся.

### Служба crocelld

Так ядро будет работать под приложением: служба от root держит туннель и отвечает по gRPC на unix-сокете `/run/crocell/crocelld.sock`. Пускает она только root и пользователя, который её поставил, а uid проверяет по самому соединению.

```bash
make install-daemon          # копирует в /usr/local/bin, ставит и запускает systemd-юнит
bin/crocell ctl add 'https://example.com/sub/…'
bin/crocell ctl mode tun     # или proxy
bin/crocell ctl rule direct proc:steam geosite:category-ru geoip:ru
bin/crocell ctl rule proxy geosite:ru-blocked *.wiseless.net
bin/crocell ctl connect nlWISELESS
bin/crocell ctl watch
```

Подписки и настройки лежат в `/var/lib/crocell/state.enc`, зашифрованные ключом из `/etc/credstore.encrypted/crocell-state-key`. Убрать службу: `sudo bin/crocelld uninstall`. Пока служба ставится только на Linux, на macOS и Windows `crocelld` запускается руками.

### Клиент

Клиент ничего не знает про протоколы: он говорит с `crocelld` по сокету и сам прописывает системный прокси, когда выбран этот режим. Без службы он покажет, как её поставить.

```bash
cd app
flutter run -d linux
```

Чтобы направить клиент на демон, запущенный руками, задайте `CROCELL_SOCKET=/путь/к/crocelld.sock`. Код клиента для API генерируется вместе с Go: `make proto` в `core/` (нужен `dart pub global activate protoc_plugin`).

## Сборки и релизы

Исходники живут на git.wiseless.net, оттуда они сами уходят в зеркало [github.com/WiselessGroup/Crocell](https://github.com/WiselessGroup/Crocell). Собирает всё GitHub Actions ([build.yml](.github/workflows/build.yml)): тесты ядра и клиента, AppImage, а также проверочные сборки под Windows, macOS и Android. Эти три пока никуда не публикуются, потому что ни службы, ни VPN-слоя под них ещё нет.

Релиз выпускается тегом:

```bash
git tag v0.3.0 && git push origin v0.3.0
```

Зеркало передаёт тег на GitHub, а workflow выкладывает в релиз `Crocell-x86_64.AppImage` и `.zsync`. Ссылка на обновления зашита в сам образ, поэтому Gear Lever и AppImageUpdate подтягивают новые версии сами. Служба ставится прямо из образа:

```bash
sudo ./Crocell-x86_64.AppImage crocelld install
```

Если у root нет FUSE, сработает `--appimage-extract-and-run` перед `crocelld`. После обновления образа службу надо переустановить той же командой, иначе продолжит работать старая.

AppImage можно собрать и локально, это `scripts/build-appimage.sh [версия]`. Нужен `appimagetool` в PATH, а без него скрипт останавливается на готовой `dist/AppDir`.

## Лицензия

[GPL-3.0](LICENSE). Crocell построен на [mihomo](https://github.com/MetaCubeX/mihomo), который тоже под GPL-3.0.
