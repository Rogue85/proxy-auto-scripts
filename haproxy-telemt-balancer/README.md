# telemt-haproxy-balancer

HAProxy в Docker на вашем сервере: приём трафика (по умолчанию `443`) и балансировка на один или несколько внешних **telemt** с `send-proxy-v2`. Сам telemt здесь не ставится — только входной прокси.

**Нужно:** Linux, Docker, доступ до telemt.

## Запуск (монолит с GitHub)

Запустить:

```bash
curl -fsSL https://raw.githubusercontent.com/Rogue85/proxy-auto-scripts/main/dist/telemt-haproxy-balancer.sh -o telemt-haproxy-balancer.sh && bash telemt-haproxy-balancer.sh
```

Или через `wget`:

```bash
wget -O telemt-haproxy-balancer.sh https://raw.githubusercontent.com/Rogue85/proxy-auto-scripts/main/dist/telemt-haproxy-balancer.sh && bash telemt-haproxy-balancer.sh
```

Откроется меню (установка, логи, статус, удаление). Повторный запуск того же скрипта — обновление конфигурации.

## Локально из репозитория

Нужен полный клон монорепозитория (рядом каталог `common/`). Из корня пакета:

```bash
bash build.sh
```

Артефакт: `../dist/telemt-haproxy-balancer.sh`. Либо из корня репозитория: `make` / `bash build_all.sh`.

Разработка без монолита: `bash src/install.sh`, меню — `bash src/start.sh`, утилиты — `bash src/utils.sh logs|status|remove`.

## Ссылки

- [telemt](https://github.com/telemt/telemt)
- [Double-hop / HAProxy + telemt](https://github.com/telemt/telemt/blob/main/docs/VPS_DOUBLE_HOP.ru.md)
