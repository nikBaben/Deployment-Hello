# Deployment-Hello

Небольшой учебный деплой: интернет → NGINX:80 → FastAPI:8000.
Два контейнера, без базы данных, Kubernetes и сборки исходников на сервере.

## Как работает

В [Account-Service-Hello](https://github.com/nikBaben/Account-Service-Hello) проходят тесты и сборка. Его workflow отдельным SSH deploy key коммитит новый digest в `image.env`. Push этого файла в `main` запускает `.github/workflows/deploy.yml`.

Workflow передаёт четыре файла на сервер: `compose.yaml`, `nginx.conf`, `image.env`, `deploy.sh`. Скрипт скачивает готовые образы, обновляет контейнеры, проверяет HTTP 200 от API через NGINX и отмечает успешный выпуск ссылкой `current`. Точное тело ответа проверяется тестами приложения; изменение текста не требует правок Deployment.

## Где что лежит

- Адрес: http://45.155.204.229/
- Релизы: `/home/deploy/hello-demo/releases/<SHA коммита Deployment>`.
- Последний успешный выпуск: `/home/deploy/hello-demo/current`.
- Docker Compose project: `hello-demo`.
- API доступен только из Docker-сети; наружу опубликован NGINX на TCP 80.

`image.env` хранит только ссылку на образ, это не секрет. Образ учебного приложения опубликован в GHCR публично, поэтому серверу не нужен пароль от registry.

## Секреты GitHub Actions

- `DEPLOY_HOST`: IP сервера.
- `DEPLOY_SSH_KEY`: отдельный приватный SSH-ключ пользователя deploy для этого примера.
- `DEPLOY_KNOWN_HOSTS`: проверенный публичный ключ SSH-сервера.

SSH-ключ на сервере записан с `restrict`: без интерактивного терминала и проброса портов. Пользователь deploy состоит в группе docker, поэтому его ключ даёт широкие права на сервере; хранить его нужно только в Actions Secrets.

## Управление на сервере

```bash
cd /home/deploy/hello-demo/current
docker compose --env-file image.env ps
docker compose --env-file image.env logs --tail 100
```

## Выпуск и откат

Обычный выпуск: push кода в main Account-Service-Hello — дальше всё автоматически.
Изменения `image.env`, `compose.yaml`, `nginx.conf`, `deploy.sh` или самого workflow автоматически запускают деплой после push в main. Повторить запуск можно кнопкой **Actions → Deploy hello world → Run workflow**.
Откат: вернуть предыдущий digest в `image.env`, закоммитить и отправить в main Deployment-Hello. Для остановки автоматических выпусков можно отключить workflow приложения или удалить его write deploy key в настройках Deployment-Hello.

## Границы примера

Это HTTP-пример, HTTPS не настроен. Он передаёт только публичный `hello world`; пароли и токены через него передавать нельзя. При замене единственного API-контейнера возможен короткий перерыв в ответах. Если проверка выпуска упала, workflow показывает ошибку и логи; автоматического отката нет. Старые образы и каталоги релизов автоматически не удаляются. Один сервер остаётся единой точкой отказа.

Текущий полнофункциональный Account-Service из Test-CI-CD работает отдельно, в `/opt/account-service`.
