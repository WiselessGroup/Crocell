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
- **Туннель всей системы** _(в работе)_. TUN, роутинг по правилам и по приложениям.

## Как устроено

```
app/          клиент на Flutter: интерфейс, никакой логики протоколов
core/         ядро на Go поверх mihomo: подписки, проверки, туннель
  cmd/crocell   CLI для разработки и отладки
proto/        контракт клиента и ядра
assets/brand/ логотип и иконки
```

На десктопе туннель держит отдельный процесс ядра, окно только с ним разговаривает: закрыли, обновили или уронили окно — VPN не моргнёт. На телефонах ядро живёт внутри системного VPN-сервиса.

## Разработка

Нужны Go 1.26+ и Flutter 3.47+.

```bash
cd core
go test ./...
go run ./cmd/crocell nodes 'https://example.com/sub/…'
go run ./cmd/crocell up 'https://example.com/sub/…' --node 'nlWISELESS'
```

`crocell up` поднимает mixed-прокси на `127.0.0.1:7890` через выбранную ноду: удобно проверять ядро без клиента и без прав.

```bash
cd app
flutter run -d linux
```

## Лицензия

[GPL-3.0](LICENSE). Crocell построен на [mihomo](https://github.com/MetaCubeX/mihomo), который тоже под GPL-3.0.
