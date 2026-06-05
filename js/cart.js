const Cart = {
  key: 'vitrina_cart',

  get() {
    try {
      return JSON.parse(localStorage.getItem(this.key)) || [];
    } catch { return []; }
  },

  save(items) {
    localStorage.setItem(this.key, JSON.stringify(items));
    this.updateBadge();
    this.renderPreview();
  },

  add(product) {
    const items = this.get();
    const exist = items.find(i => i.id === product.id);
    if (exist) {
      exist.qty += 1;
    } else {
      items.push({ id: product.id, name: product.name, price: product.price, qty: 1, image: product.image });
    }
    this.save(items);
    this.showAdded(product.name);
  },

  remove(id) {
    this.save(this.get().filter(i => i.id !== id));
  },

  updateQty(id, qty) {
    const items = this.get();
    const item = items.find(i => i.id === id);
    if (item) {
      if (qty <= 0) return this.remove(id);
      item.qty = qty;
      this.save(items);
    }
  },

  clear() {
    this.save([]);
  },

  getTotal() {
    return this.get().reduce((s, i) => s + i.price * i.qty, 0);
  },

  getCount() {
    return this.get().reduce((s, i) => s + i.qty, 0);
  },

  updateBadge() {
    const badge = document.getElementById('cart-badge');
    if (badge) {
      const count = this.getCount();
      badge.textContent = count || '';
      badge.style.display = count ? 'flex' : 'none';
    }
  },

  showAdded(name) {
    const toast = document.getElementById('toast');
    if (!toast) return;
    toast.textContent = `✓ ${name} добавлен в корзину`;
    toast.classList.add('show');
    clearTimeout(toast._timer);
    toast._timer = setTimeout(() => toast.classList.remove('show'), 2000);
  },

  renderPreview() {
    const el = document.getElementById('cart-preview');
    const totalEl = document.getElementById('cart-total');
    if (!el) return;
    const items = this.get();
    if (!items.length) {
      el.innerHTML = '<p class="cart-empty">Корзина пуста</p>';
      if (totalEl) totalEl.textContent = '0 ₽';
      return;
    }
    el.innerHTML = items.map(i => `
      <div class="cart-item" data-id="${i.id}">
        <img src="${i.image || 'img/no-image.svg'}" alt="${i.name}" class="cart-item-img">
        <div class="cart-item-info">
          <div class="cart-item-name">${i.name}</div>
          <div class="cart-item-price">${(i.price * i.qty).toLocaleString()} ₽</div>
        </div>
        <div class="cart-item-qty">
          <button class="qty-btn" onclick="Cart.updateQty('${i.id}', ${i.qty - 1})">−</button>
          <span>${i.qty}</span>
          <button class="qty-btn" onclick="Cart.updateQty('${i.id}', ${i.qty + 1})">+</button>
        </div>
        <button class="cart-item-remove" onclick="Cart.remove('${i.id}')">✕</button>
      </div>
    `).join('');
    if (totalEl) totalEl.textContent = this.getTotal().toLocaleString() + ' ₽';
  },

  show() {
    document.getElementById('cart-overlay').classList.add('open');
    document.body.classList.add('no-scroll');
    this.renderPreview();
  },

  hide() {
    document.getElementById('cart-overlay').classList.remove('open');
    document.body.classList.remove('no-scroll');
  },

  async checkout() {
    const items = this.get();
    if (!items.length) return;
    const name = document.getElementById('checkout-name').value.trim();
    const phone = document.getElementById('checkout-phone').value.trim();
    const comment = document.getElementById('checkout-comment').value.trim();
    if (!name || !phone) {
      alert('Заполните имя и телефон');
      return;
    }
    try {
      const btn = document.querySelector('.checkout-btn');
      btn.disabled = true;
      btn.textContent = 'Отправка...';
      await API.createOrder(items, { name, phone, comment });
      this.clear();
      this.hide();
      alert('Заказ отправлен! Менеджер свяжется с вами.');
    } catch (e) {
      alert('Ошибка отправки заказа. Попробуйте позже.');
      console.error(e);
    } finally {
      const btn = document.querySelector('.checkout-btn');
      if (btn) { btn.disabled = false; btn.textContent = 'Отправить заказ'; }
    }
  },
};
