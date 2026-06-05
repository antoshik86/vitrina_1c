const API = {
  // Адрес сервера 1С (HTTP-сервисы). ЗАМЕНИТЬ на свой!
  // Если 1С доступен из интернета и поддерживает CORS:
  //   base: 'https://your-1c-server.ru/hs/vitrina'
  // Если используете PHP-прокси (api/proxy.php):
  //   base: '/api'
  base: '/hs/vitrina',

  async request(method, path, body) {
    const url = this.base + path;
    const opts = {
      method,
      headers: { 'Content-Type': 'application/json' },
    };
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch(url, opts);
    if (!res.ok) throw new Error(`API error ${res.status}`);
    return res.json();
  },

  getCatalog() {
    return this.request('GET', '/catalog');
  },

  getProduct(id) {
    return this.request('GET', `/product/${id}`);
  },

  getCategories() {
    return this.request('GET', '/categories');
  },

  createOrder(items, clientInfo) {
    return this.request('POST', '/order', { items, clientInfo });
  },

  getChatHistory() {
    return this.request('GET', '/chat/messages');
  },

  sendChatMessage(text, type = 'manager') {
    return this.request('POST', '/chat/message', { text, type });
  },

  askAI(text) {
    return this.request('POST', '/chat/ai', { text });
  },
};
