# README — Обзор репозитория

Короткое описание решения: репозиторий объединяет фронтенд (Flutter Web, развёртывание через Nginx/Docker), сервис поиска по нормативно-правовым актам (LLM-агент на FastAPI) и спецификацию входных данных для аналитических модулей. Документация разбита на отдельные `.md` файлы для быстрого онбординга и удобной навигации.

---

## Быстрый старт

1) Ознакомьтесь с форматом входных данных и связями сущностей:  
   **[Формат входных данных](./dataIN.md)**

2) Запустите сервис вопросов-ответов по НПА (локальный API, Swagger/ReDoc):  
   **[NPA QA LLM Agent](./LLM%20agent.md)**

3) Соберите и разверните фронтенд (Flutter Web), при необходимости — балансировку через Nginx/Docker и сборки под ПК/Android/iOS:  
   **[Развёртывание Flutter и компиляция](./flutter%20compile.md)**

---

## Быстрое развертывание (TL;DR)

### Вариант A — через Docker Compose (рекомендуется)

~~~bash
# 0) Клонирование
git clone <repo-url> && cd <repo-name>

# 1) (Опционально) переменные окружения
cp .env.example .env    # отредактируйте при необходимости

# 2) Сборка и запуск всех сервисов
docker compose up -d --build

# 3) Проверки доступности
curl http://localhost:8010/health     # API НПА должен вернуть статус
# Откройте фронтенд в браузере:
# http://localhost/
~~~

**Типовой docker-compose (пример, адаптируйте пути под ваш репозиторий):**

~~~yaml
version: "3.9"
services:
  npa-api:
    build:
      context: ./npa-api
      dockerfile: Dockerfile
    ports:
      - "8010:8010"
    environment:
      - APP_ENV=prod
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:8010/health"]
      interval: 10s
      timeout: 3s
      retries: 5

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    # Если артефакты собираются внутри контейнера:
    command: sh -lc "flutter build web && cp -r build/web /dist"
    volumes:
      - ./frontend/build/web:/dist

  web:
    image: nginx:alpine
    depends_on:
      - frontend
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./frontend/build/web:/usr/share/nginx/html:ro
~~~

**Пример Nginx-конфигурации для проксирования API:**

~~~nginx
server {
  listen 80;
  server_name _;
  root /usr/share/nginx/html;
  index index.html;

  location / {
    try_files $uri $uri/ /index.html;
  }

  location /ask {
    proxy_pass http://npa-api:8010/ask;
  }

  location /health {
    proxy_pass http://npa-api:8010/health;
  }
}
~~~

> Примечание: Если в репозитории уже присутствуют готовые `docker-compose.yml` и `nginx.conf` (см. *flutter compile.md*), используйте их без изменений.

---

### Вариант B — локально без Docker (режим разработки)

**API НПА (FastAPI/uvicorn):**

~~~bash
cd npa-api
python -m venv .venv && . .venv/bin/activate
pip install -r requirements.txt
# Конкретная команда запуска описана в "LLM agent.md".
# Типовой вариант:
uvicorn app:app --host 0.0.0.0 --port 8010 --reload
~~~

**Фронтенд (Flutter Web):**

~~~bash
cd frontend
flutter pub get
# Запуск в браузере (горячая перезагрузка):
flutter run -d chrome

# Либо сборка и локальная раздача статического билда:
flutter build web
python -m http.server 8080 -d build/web
# Откройте http://localhost:8080/
~~~

**Важно:** при локальном запуске без Nginx убедитесь, что фронтенд обращается к правильному адресу API (обычно это настраивается в конфигурации фронтенда, см. *flutter compile.md* и *LLM agent.md*). При обращениях напрямую к FastAPI включите CORS в приложении.

---

## Документация (MD)

- **dataIN.md** — описание JSON-схем входных данных, ключей, проверок целостности, рекомендуемых джоинов, оговорок по полям и единицам измерения.  
- **LLM agent.md** — руководство по запуску FastAPI-сервиса (NPA QA LLM Agent), описание возможностей, эндпоинтов (`/health`, `/ask`), примеров запросов, а также ссылок на `/docs` (Swagger) и `/redoc`.  
- **flutter compile.md** — чек-лист сборки Flutter Web, рекомендации по PWA/кэшированию, примеры `docker-compose.yml` и конфигурации Nginx, а также инструкции по сборке под Desktop/Android/iOS.

---

## Навигация по задачам

- **Данные** → *dataIN.md*: структура и требования к JSON-файлам.  
- **API НПА** → *LLM agent.md*: запуск сервиса ответов по НПА, интеграция, отладка.  
- **Фронтенд/Инфра** → *flutter compile.md*: сборка артефактов, деплой, балансировка, диагностика.

---

## Принципы интеграции

- Единый идентификатор для объединения таблиц аналитики — `product_code` (см. *dataIN.md*).  
- Сервис НПА работает локально по данным JSON без внешних API (см. *LLM agent.md*).  
- Для продакшн-развёртываний фронтенда используйте статическую отдачу через Nginx и неизменяемое кэширование артефактов (см. *flutter compile.md*).

---

## Мини-план проверки окружения

~~~bash
# 1) Проверка Flutter SDK
flutter --version && flutter doctor -v

# 2) Проверка API НПА (после запуска uvicorn)
curl http://127.0.0.1:8010/health

# 3) Проверка отдачи фронтенда/Nginx (после docker compose up)
curl -I http://localhost/
~~~

---

## Поддержка и расширение

- Добавляйте новые источники данных в соответствии с правилами типизации и валидации (*dataIN.md*).  
- Расширяйте парсинг и эвристику поиска в LLM-агенте через регулярные выражения/сигналы семантики (*LLM agent.md*).  
- Расширяйте базу знаний агента через добавления списка НПА с правилами типизации и валидации (*LLM agent.md*)
- Обновляйте политику кэширования и настройки PWA при релизах фронтенда (*flutter compile.md*).
