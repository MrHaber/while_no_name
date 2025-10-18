# README — Развертывание Flutter-сайта и компиляция приложения на разные устройстыа

## Содержание
- [Общая архитектура](#общая-архитектура)
- [Системные требования](#системные-требования)
- [Структура сборки Flutter Web](#структура-сборки-flutter-web)
- [Сборка артефактов Flutter](#сборка-артефактов-flutter)
- [Развёртывание в Docker + Nginx (балансировщик)](#развёртывание-в-docker--nginx-балансировщик)
  - [Файлы и директории](#файлы-и-директории)
  - [docker-compose.yml](#docker-composeyml)
  - [Конфигурация Nginx](#конфигурация-nginx)
  - [Переменные окружения (.env)](#переменные-окружения-env)
  - [Старт/останов/обновление](#стартостановобновление)
- [Оптимизация отдачи статики](#оптимизация-отдачи-статики)
- [Диагностика и мониторинг](#диагностика-и-мониторинг)
- [Команда разработки: сборки для ПК, Android и iOS](#команда-разработки-сборки-для-пк-android-и-ios)
  - [Desktop (Windows / macOS / Linux)](#desktop-windows--macos--linux)
  - [Android](#android)
  - [iOS](#ios)
- [Типовые проблемы и решения](#типовые-проблемы-и-решения)
- [Политика кэширования и PWA](#политика-кэширования-и-pwa)
- [Безопасность](#безопасность)
- [Лицензирование и атрибуция](#лицензирование-и-атрибуция)

---

## Общая архитектура

Приложение состоит из:
1. **Flutter Web** фронтенда (собранная статика `build/web`).
2. **Nginx** как фронтовой веб-сервер и **балансировщик нагрузки**.
3. **LLP-агента поддержки** (один или несколько контейнеров), к которому Nginx проксирует запросы по префиксу, например, `/llp/`, используя стратегию `least_conn` для балансировки.

Маршрутизация на уровне Nginx:
- `/` — отдача статических файлов Flutter, fallback на `index.html` для поддержки HTML5 routing.
- `/llp/` — проксирование на пул контейнеров LLP-агента.

---

## Системные требования

- Docker 24+ и Docker Compose v2.
- Flutter SDK 3.22+ (для сборки фронтенда).
- OpenSSL 1.1+ (если используется TLS-терминация на стороне Nginx).
- 1 vCPU и 512–1024 MB RAM на каждый экземпляр LLP-агента; 1 vCPU и 256–512 MB RAM на фронтовой Nginx (минимальные ориентиры).

---

## Структура сборки Flutter Web

Структура в корне каталога сборки (`build/web`) соответствует следующему виду:

```
build/
└─ web/
   ├─ assets/
   ├─ canvaskit/
   ├─ icons/
   ├─ .last_build_id
   ├─ favicon.png
   ├─ flutter.js
   ├─ flutter_bootstrap.js
   ├─ flutter_service_worker.js
   ├─ index.html
   ├─ main.dart.js
   ├─ manifest.json
   └─ version.json
```

> В репозитории рекомендуется хранить `build/web` только как артефакт релиза (например, через CI), а исходники Flutter — отдельно.

---

## Сборка артефактов Flutter

1) Установить Flutter и включить поддержку web:
```
flutter --version
flutter doctor -v
flutter config --enable-web
```

2) Собрать production-сборку:
```
flutter build web --release --pwa-strategy=offline-first
# артефакты окажутся в build/web
```

> Флаг `--pwa-strategy=offline-first` добавляет service worker. Если PWA не требуется, уберите флаг или используйте `none`.

---

## Развёртывание в Docker + Nginx (балансировщик)

### Файлы и директории

Рекомендуемая структура репозитория для развёртывания:

```
.
├─ build/
│  └─ web/                   # итоговая статика Flutter
├─ docker/
│  ├─ nginx/
│  │  ├─ nginx.conf          # базовый конфиг
│  │  └─ conf.d/
│  │     └─ site.conf        # vhost для сайта и балансировки
│  └─ llp-agent/             # (опционально) Dockerfile LLP-агента, если собираете свой образ
├─ .env                      # переменные окружения Compose
└─ docker-compose.yml
```

### docker-compose.yml

Пример `docker-compose.yml` с одним Nginx и пулом из двух экземпляров LLP-агента:

```
services:
  nginx:
    image: nginx:1.27-alpine
    container_name: web-nginx
    ports:
      - "${HTTP_PORT:-80}:80"
      # - "${HTTPS_PORT:-443}:443"   # включите при наличии TLS
    volumes:
      - ./build/web:/var/www/app:ro
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./docker/nginx/conf.d:/etc/nginx/conf.d:ro
      # - ./certs:/etc/nginx/certs:ro  # если используете TLS
    depends_on:
      - llp-agent-1
      - llp-agent-2
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost/healthz || exit 1"]
      interval: 15s
      timeout: 3s
      retries: 3

  llp-agent-1:
    image: your-registry/llp-agent:latest
    container_name: llp-agent-1
    environment:
      - LLP_LOG_LEVEL=info
    expose:
      - "8080"
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
      interval: 15s
      timeout: 3s
      retries: 3

  llp-agent-2:
    image: your-registry/llp-agent:latest
    container_name: llp-agent-2
    environment:
      - LLP_LOG_LEVEL=info
    expose:
      - "8080"
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
      interval: 15s
      timeout: 3s
      retries: 3

networks:
  default:
    name: flutter-llp-net
    driver: bridge
```

> Замените `your-registry/llp-agent:latest` на реальный образ агента. Если образа нет, см. пример Dockerfile в каталоге `docker/llp-agent/`.

### Конфигурация Nginx

`docker/nginx/nginx.conf` — минимальная базовая конфигурация:

```
user  nginx;
worker_processes auto;

events {
  worker_connections 1024;
}

http {
  include       /etc/nginx/mime.types;
  default_type  application/octet-stream;

  sendfile        on;
  tcp_nopush      on;
  tcp_nodelay     on;
  keepalive_timeout 65;

  # Сжатие
  gzip on;
  gzip_types text/plain text/css application/json application/javascript application/font-woff application/font-woff2 image/svg+xml;
  gzip_min_length 1400;

  include /etc/nginx/conf.d/*.conf;
}
```

`docker/nginx/conf.d/site.conf` — сайт + балансировка LLP:

```
# Пул агентов поддержки
upstream llp_pool {
  least_conn;
  server llp-agent-1:8080 max_fails=3 fail_timeout=30s;
  server llp-agent-2:8080 max_fails=3 fail_timeout=30s;
}

map $http_upgrade $connection_upgrade {
  default upgrade;
  ''      close;
}

server {
  listen 80;
  server_name _;

  # Корень с артефактами Flutter
  root /var/www/app;
  index index.html;

  # Health-endpoint для оркестратора
  location = /healthz { return 200 'ok'; add_header Content-Type text/plain; }

  # Кэширование статических артефактов (хешированные имена файлов)
  location ~* \.(?:js|css|png|jpg|jpeg|gif|svg|ico|webp|woff2?)$ {
    expires 30d;
    add_header Cache-Control "public, max-age=2592000, immutable";
    try_files $uri =404;
  }

  # Service Worker и манифест — никогда не кэшировать агрессивно
  location = /flutter_service_worker.js { add_header Cache-Control "no-cache, no-store, must-revalidate"; try_files $uri =404; }
  location = /manifest.json              { add_header Cache-Control "no-cache, no-store, must-revalidate"; try_files $uri =404; }
  location = /version.json               { add_header Cache-Control "no-cache, no-store, must-revalidate"; try_files $uri =404; }

  # PWA: позволяем SW обслуживать корень
  add_header Service-Worker-Allowed /;

  # HTML5 pushState — fallback на index.html
  location / {
    try_files $uri $uri/ /index.html;
  }

  # Проксирование в LLP-агента (REST/WebSocket)
  location /llp/ {
    proxy_http_version 1.1;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_set_header Upgrade           $http_upgrade;
    proxy_set_header Connection        $connection_upgrade;

    proxy_read_timeout 300s;
    proxy_send_timeout 300s;

    proxy_pass http://llp_pool/;
  }
}
```

> Если агент использует сервер-события или WebSocket, блок `Upgrade/Connection` обязателен.

### Переменные окружения (.env)

`.env` в корне проекта:

```
HTTP_PORT=80
# HTTPS_PORT=443
# Дополнительные переменные для LLP/NGINX при необходимости
```

### Старт/останов/обновление

1) Сборка фронтенда:
```
flutter build web --release --pwa-strategy=offline-first
```

2) Поднять стек:
```
docker compose up -d
docker compose ps
```

3) Проверить:
```
curl -I http://localhost/
curl -I http://localhost/healthz
curl -I http://localhost/manifest.json
curl -i http://localhost/llp/health   # если у агента есть такой endpoint
```

4) Обновить фронтенд (без простоя):
```
flutter build web --release
docker compose exec nginx nginx -s reload
# При сильных изменениях:
# docker compose restart nginx
```

---

## Оптимизация отдачи статики

- Используйте хэшированные имена файлов (Flutter делает это по умолчанию для основных бандлов).
- Включите `gzip` (см. `nginx.conf`). Для Brotli потребуется модуль Nginx с поддержкой brotli или отдельный образ.
- Убедитесь, что `flutter_service_worker.js` не кэшируется браузером (см. `no-cache` правила).

---

## Диагностика и мониторинг

- Логи:
```
docker compose logs -f nginx
docker compose logs -f llp-agent-1
docker compose logs -f llp-agent-2
```

- Проверьте балансировку: выполните несколько запросов к `/llp/` и убедитесь, что ответы приходят поочерёдно от разных инстансов (если агент пишет идентификатор экземпляра в ответ).

- Статистика Nginx (опционально):
  добавьте в `server {}`:
  ```
  location /nginx_status {
    stub_status on;
    allow 127.0.0.1;
    deny all;
  }
  ```
  и подключите через SSH-туннель или защитите базовой аутентификацией.

---

## Команда разработки: сборки для ПК, Android и iOS

### Desktop (Windows / macOS / Linux)

1) Активировать нужные цели:
```
# Windows
flutter config --enable-windows-desktop

# macOS
flutter config --enable-macos-desktop

# Linux
flutter config --enable-linux-desktop
```

2) Запуск в отладке:
```
flutter devices
flutter run -d windows   # или macos / linux
```

3) Релизные сборки:
```
flutter build windows
flutter build macos
flutter build linux
```

> Для Linux может потребоваться наличие зависимостей GTK/Clang. Для Windows — Visual Studio с наборами C++ Desktop.

### Android

1) Подготовка окружения:
- Установить Android Studio, SDK, Platform-Tools.
- Включить эмулятор или подключить реальное устройство (USB debugging).

2) Отладка:
```
flutter devices
flutter run -d android
```

3) Релизные сборки:
- APK:
  ```
  flutter build apk --release
  ```
- App Bundle (для публикации в Google Play):
  ```
  flutter build appbundle --release
  ```
- Подпись:
  ```
  # Создайте keystore (один раз)
  keytool -genkey -v -keystore android/app/release.keystore -alias upload -keyalg RSA -keysize 2048 -validity 36500

  # android/key.properties:
  storePassword=***
  keyPassword=***
  keyAlias=upload
  storeFile=./app/release.keystore
  ```
  В `android/app/build.gradle` подключите `keyProperties` и `signingConfigs` для release.

### iOS

1) Требования:
- macOS с Xcode 15+, установленный CocoaPods (`sudo gem install cocoapods`).

2) Инициализация и отладка:
```
cd ios
pod install
cd ..
flutter devices
flutter run -d ios
```

3) Релиз:
```
flutter build ios --release
# либо открыть ios/Runner.xcworkspace в Xcode,
# настроить Bundle ID, Team, Signing & Capabilities и собрать Archive для TestFlight/App Store.
```

> Подписывание iOS требует действующего Apple Developer аккаунта. Убедитесь, что `Deployment Info` соответствует целевым устройствам.

---

## Типовые проблемы и решения

- **Бесконечный кэш HTML после деплоя:** обновите правила кэширования для `index.html` (fallback) и `service worker`. Используйте `no-cache` для HTML и SW.
- **404 при обновлении страницы на вложенном роуте (`/route/sub`):** убедитесь, что в Nginx настроен `try_files $uri $uri/ /index.html;`.
- **WebSocket LLP обрывается:** проверьте заголовки `Upgrade/Connection` и таймауты `proxy_read_timeout`.
- **CORS-ошибки:** если фронтенд и агент на разных доменах, добавьте заголовки `Access-Control-Allow-Origin` на стороне агента или настройте единый домен за Nginx.

---

## Политика кэширования и PWA

Рекомендации:
- Для **хэшированных** JS/CSS/шрифтов — `Cache-Control: immutable, max-age=30d`.
- Для **`index.html`** — `no-cache`, чтобы получать свежую версию манифеста.
- Для **Service Worker** — всегда `no-cache`.  
- Если используете `offline-first`, не забывайте о механизме устаревших кэшей. После деплоя уведомляйте пользователи о доступности обновления (через `registration.waiting`).

---

## Безопасность

- Разносите публичный и админский путь (`/nginx_status`, `/metrics`) и ограничивайте доступ.
- Включайте TLS на внешнем периметре. Для самостоятельной терминации добавьте сервер на `listen 443 ssl;` и подключите `ssl_certificate`/`ssl_certificate_key`.
- Ограничивайте размер тела запросов в LLP (например, `client_max_body_size 10m;`), если передаются вложения.
- Прописывайте `Content-Security-Policy` (минимум `default-src 'self'`), если нет сторонних источников.
- Регулярно обновляйте образы `nginx:alpine` и образ LLP-агента.

---

## Лицензирование и атрибуция

- Flutter и Nginx распространяются под соответствующими лицензиями (BSD-style / BSD-like).  
- При публикации артефактов в публичные реестры указывайте лицензии компонента LLP-агента и сторонних библиотек.

```
# Пример CSP (добавьте в server{} при необходимости):
add_header Content-Security-Policy "default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self' wss: https:; font-src 'self' data:" always;
```

