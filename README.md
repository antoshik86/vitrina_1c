# Витрина 1С (УНФ) — статический интернет-магазин

Готовая вёрстка витрины товаров с корзиной и чатом для интеграции с **1С:Управление нашей фирмой (УНФ)**.

## Архитектура

```
[Хостинг (GitHub Pages / Netlify)]  ←  [1С:УНФ (HTTP-сервисы)]
         ↓                                      ↓
   index.html, product.html               /hs/vitrina/...
   css/style.js                          GET  /catalog
   js/api.js, cart.js, chat.js           POST /order
                                          POST /chat/ai
```

- **Фронтенд** — чистый HTML/CSS/JS, никаких зависимостей. Хостится бесплатно.
- **Бэкенд** — HTTP-сервисы 1С (публикуются через веб-сервер, где стоит 1С).
- **Заказы** — создаются в 1С как документы `ЗаказПокупателя`.
- **Чат** — AI-ассистент + передача менеджеру.

## Состав проекта

| Файл | Назначение |
|------|-----------|
| `index.html` | Главная страница: каталог, поиск, корзина, чат |
| `product.html` | Детальная карточка товара |
| `css/style.css` | Все стили (адаптивные, mobile-first) |
| `js/api.js` | Слой для вызова HTTP-сервисов 1С |
| `js/cart.js` | Логика корзины (localStorage) |
| `js/chat.js` | Чат-виджет (AI + менеджер) |
| `js/app.js` | Основной скрипт каталога |
| `img/no-image.svg` | Заглушка отсутствующего изображения |
| `1c/HTTP_Services.md` | Спецификация HTTP-сервисов 1С |
| `1c/generate_vitrina.bsl` | Генерация статических HTML-карточек из 1С |
| `1c/vitrina_http_service_handler.bsl` | Хендлер HTTP-сервиса (шаблон) |

## Быстрый старт

### 1. Фронтенд — на бесплатный хостинг

**GitHub Pages:**
```bash
git init && git add . && git commit -m "vitrina"
# Создать репозиторий на GitHub
git remote add origin https://github.com/user/vitrina.git
git push -u origin main
# В Settings → Pages → Source: main, /root
```

**Netlify:**
Перетащить папку на https://app.netlify.com/drop

### 2. 1С — настроить HTTP-сервисы

1. Открыть конфигурацию УНФ в режиме Конфигуратор
2. Добавить HTTP-сервис `vitrina`
3. Реализовать методы по спецификации `1c/HTTP_Services.md`
4. Опубликовать на веб-сервере (Apache / IIS / Nginx)
5. Убедиться, что CORS-заголовки проставляются

### 3. Настроить API.base в js/api.js

```js
const API = {
  base: 'https://your-1c-server.ru/hs/vitrina',
  // ...
};
```

### 4. AI-ассистент

В `POST /hs/vitrina/chat/ai` можно реализовать:
- Интеграцию с **GigaChat** (Сбер, бесплатно для РФ)
- Интеграцию с **OpenAI API**
- Простой поиск по каталогу (ключевые слова → товары)

## Настройка 1С: генерация статических HTML

Внешняя обработка `1c/generate_vitrina.bsl`:
1. Загрузить в 1С как внешнюю обработку
2. Указать путь до каталога на диске
3. Нажать "Сформировать"
4. Готовые HTML-файлы скопировать на хостинг

## Варианты хостинга

| Платформа | Бесплатно | Особенности |
|-----------|-----------|-------------|
| GitHub Pages | ✅ | 1 ГБ, SSL |
| Netlify | ✅ | SSL, Forms |
| Vercel | ✅ | SSL, Edge Functions |
| Cloudflare Pages | ✅ | SSL, Unlimited bandwidth |
