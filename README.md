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
- **Понятное качество нод** _(в работе)_. Вместо «пинг 5000» — где у конфига вход, где выход, открываются ли нужные сайты.
- **Два режима подключения.** Системный прокси для браузеров и приложений, которые его слушаются, и TUN, когда через VPN идёт вся система, включая программы, которые про прокси не знают или не дают его отключить. Роутинг по правилам и по приложениям _(в работе)_.

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
make install-daemon          # копирует в /usr/local/lib/crocell, ставит и запускает systemd-юнит
bin/crocell ctl add 'https://example.com/sub/…'
bin/crocell ctl mode tun     # или proxy
bin/crocell ctl app steam bypass
bin/crocell ctl connect nlWISELESS
bin/crocell ctl watch
```

Подписки и настройки лежат в `/var/lib/crocell/state.json` (только для root). Убрать службу: `sudo bin/crocelld uninstall`. Пока служба ставится только на Linux, на macOS и Windows `crocelld` запускается руками.

### Клиент

```bash
cd app
flutter run -d linux
```

## Лицензия

[GPL-3.0](LICENSE). Crocell построен на [mihomo](https://github.com/MetaCubeX/mihomo), который тоже под GPL-3.0.
