# telemt-haproxy-balancer

HAProxy в Docker на вашем сервере: приём трафика (по умолчанию `443`) и балансировка на один или несколько внешних **telemt** с `send-proxy-v2`. Сам telemt здесь не ставится — только входной прокси.

**Нужно:** Linux, Docker, доступ до telemt. Запуск **от root** или через **`sudo bash …`** (установка Docker, `docker run` с `--network host` и `--user 0:0`).

При установке Docker проверяется и при необходимости ставится **в начале**, до вопросов про upstream.

Слушать **443** при `--network host` с образом `haproxy` (процесс по умолчанию не root) на части ядер даёт `Permission denied`, даже с `NET_BIND_SERVICE`. Контейнер поэтому запускается с **`--user 0:0`**, чтобы биндить привилегированный порт без sysctl на хосте. Если политика запрещает root в контейнере — слушайте порт **≥1024** или задайте на хосте `net.ipv4.ip_unprivileged_port_start=0` и уберите `--user` в своём форке.

## Запуск (монолит с GitHub)

Запустить:

```bash
curl -fsSL https://raw.githubusercontent.com/Rogue85/proxy-auto-scripts/main/dist/telemt-haproxy-balancer.sh -o telemt-haproxy-balancer.sh && sudo bash telemt-haproxy-balancer.sh
```

Или через `wget`:

```bash
wget -O telemt-haproxy-balancer.sh https://raw.githubusercontent.com/Rogue85/proxy-auto-scripts/main/dist/telemt-haproxy-balancer.sh && sudo bash telemt-haproxy-balancer.sh
```

Откроется меню (установка, логи, статус, удаление). Повторный запуск того же скрипта — обновление конфигурации.

## Локально из репозитория

Нужен полный клон монорепозитория (рядом каталог `common/`). Из корня пакета:

```bash
bash build.sh
```

Артефакт: `../dist/telemt-haproxy-balancer.sh`. Либо из корня репозитория: `make` / `bash build_all.sh`.

Разработка без монолита: `sudo bash src/install.sh`, меню — `sudo bash src/start.sh`, утилиты — `bash src/utils.sh logs|status|remove` (достаточно доступа к Docker, root не обязателен).

## Ссылки

- [telemt](https://github.com/telemt/telemt)
- [Double-hop / HAProxy + telemt](https://github.com/telemt/telemt/blob/main/docs/VPS_DOUBLE_HOP.ru.md)
