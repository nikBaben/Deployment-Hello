# Deployment-Hello

Небольшой учебный деплой: интернет → NGINX:80 → FastAPI:8000 или Catalog на Go:8080.
Три контейнера, без базы данных, Kubernetes и сборки исходников на сервере.

## Как работает

В [Account-Service-Hello](https://github.com/nikBaben/Account-Service-Hello) и [Catalog-Service-Hello](https://github.com/nikBaben/Catalog-Service-Hello) проходят собственные тесты и сборка. Каждый CI публикует только свой образ и отдельным SSH deploy key обновляет только свой файл версии: `image.env` или `catalog.env`. Push запускает `.github/workflows/deploy.yml`.

Workflow передаёт пять файлов на сервер: `compose.yaml`, `nginx.conf`, `image.env`, `catalog.env`, `deploy.sh`. Скрипт сравнивает файлы версий с последними применёнными файлами в `state/`. Он скачивает и применяет только изменившиеся сервисы. Все тесты выполняются в репозиториях приложений до публикации образов. В Deployment нет тестов, healthcheck, ожидания готовности или HTTP-проверок.

| Изменение | Команды на сервере |
| --- | --- |
| Только image.env | `compose pull api` и `compose up -d --no-deps api` |
| Только catalog.env | `compose pull catalog` и `compose up -d --no-deps catalog` |
| Оба файла версий | `compose pull api catalog` и `compose up -d --no-deps api catalog` |
| compose.yaml, nginx.conf, deploy.sh или первый запуск | Применение обоих приложений и пересоздание NGINX |
| Ничего не изменилось | Без pull и up |

Сравнение идёт с фактически применённым состоянием, а не только с предыдущим Git-коммитом. Поэтому пропущенный ожидающий запуск GitHub не теряет обновление второго сервиса. Ошибки Git-push при одновременной записи двух CI обрабатываются повтором с получением актуальной main.

Конфигурация NGINX монтируется из постоянного `/home/deploy/hello-demo/config/nginx.conf`. При смене версии только приложения NGINX не перезапускается и его файл не переписывается. Динамическое разрешение DNS Docker позволяет ему найти новый контейнер сервиса. В логах CD показываются ID контейнеров до и после применения.

## Где что лежит

- Адрес: http://45.155.204.229/
- Catalog: http://45.155.204.229/catalog/
- Релизы: `/home/deploy/hello-demo/releases/<SHA коммита Deployment>`.
- Последний применённый выпуск: `/home/deploy/hello-demo/current`.
- Применённые файлы конфигурации и версий: `/home/deploy/hello-demo/state/`.
- Docker Compose project: `hello-demo`.
- API доступен только из Docker-сети; наружу опубликован NGINX на TCP 80.

`image.env` и `catalog.env` хранят только ссылки на образы, это не секреты. Учебные образы опубликованы в GHCR публично, поэтому серверу не нужен пароль от registry.

## Секреты GitHub Actions

- `DEPLOY_HOST`: IP сервера.
- `DEPLOY_SSH_KEY`: отдельный приватный SSH-ключ пользователя deploy для этого примера.
- `DEPLOY_KNOWN_HOSTS`: проверенный публичный ключ SSH-сервера.

SSH-ключ на сервере записан с `restrict`: без интерактивного терминала и проброса портов. Пользователь deploy состоит в группе docker, поэтому его ключ даёт широкие права на сервере; хранить его нужно только в Actions Secrets.

## Управление на сервере

```bash
cd /home/deploy/hello-demo/current
export DEPLOY_ROOT="$HOME/hello-demo"
docker compose --env-file image.env --env-file catalog.env ps
docker compose --env-file image.env --env-file catalog.env logs --tail 100
```

## Выпуск и откат

Обычный выпуск: push кода в main нужного сервиса — дальше всё автоматически. CI другого сервиса не запускается, его образ не собирается и не публикуется.
Изменения `image.env`, `catalog.env`, `compose.yaml`, `nginx.conf`, `deploy.sh` или самого workflow автоматически запускают деплой после push в main. Повторить запуск можно кнопкой **Actions → Deploy changed services → Run workflow**.
Откат: вернуть предыдущий digest только в файле нужного сервиса, закоммитить и отправить в main Deployment-Hello. Остальные контейнеры не затрагиваются. Для остановки автоматических выпусков можно отключить workflow приложения или удалить его write deploy key в настройках Deployment-Hello.

## Границы примера

Это HTTP-пример, HTTPS не настроен. При замене контейнеров возможен короткий перерыв в ответах. Успешный workflow означает, что Docker скачал образы и применил конфигурацию; готовность приложения и HTTP-ответы в Deployment не проверяются. Ошибки SSH, скачивания и запуска Docker завершают workflow ошибкой; автоматического отката нет. Старые образы и каталоги релизов автоматически не удаляются. Один сервер остаётся единой точкой отказа.

Текущий полнофункциональный Account-Service из Test-CI-CD работает отдельно, в `/opt/account-service`.
