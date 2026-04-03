# Auto Scripts Collection

Репозиторий с набором автономных инфраструктурных скриптов и мини-проектов.

## Общие модули

- `common/` — переиспользуемые фрагменты между проектами (`lib_ui.sh` — вывод в терминале, `telemt_privilege.sh` — проверка root для telemt-скриптов).

## Проекты

- `haproxy-telemt-balancer` — HAProxy-балансировщик для внешних `telemt`-серверов, установка и обновление одним скриптом. Логика в `haproxy-telemt-balancer/src/`.

## Сборка

- Все проекты из списка в `build_all.sh`: `bash build_all.sh` или `make` / `make build`.
- Один пакет: `bash haproxy-telemt-balancer/build.sh` или `make haproxy-telemt-balancer`.
- Артефакты: `dist/` (например `dist/telemt-haproxy-balancer.sh`). Очистка: `make clean`.
