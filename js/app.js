const App = {
  async init() {
    Cart.updateBadge();
    this.setupCatalog();
    this.setupSearch();
    this.setupNavigation();
    this.setupCheckoutForm();
    this.loadCatalog();
  },

  setupCatalog() {
    this.catalogEl = document.getElementById('catalog');
    this.categoriesEl = document.getElementById('categories');
    this.currentCategory = null;
  },

  setupSearch() {
    const input = document.getElementById('search-input');
    if (!input) return;
    input.addEventListener('input', () => {
      clearTimeout(input._timer);
      input._timer = setTimeout(() => this.loadCatalog(input.value.trim()), 300);
    });
  },

  setupNavigation() {
    document.querySelectorAll('[data-page]').forEach(link => {
      link.addEventListener('click', e => {
        e.preventDefault();
        this.navigate(link.dataset.page);
      });
    });
  },

  setupCheckoutForm() {
    const phoneInput = document.getElementById('checkout-phone');
    if (phoneInput) {
      phoneInput.addEventListener('input', () => {
        phoneInput.value = phoneInput.value.replace(/[^+\d]/g, '');
      });
    }
  },

  async loadCatalog(search) {
    try {
      this.catalogEl.innerHTML = '<div class="catalog-loading">Загрузка...</div>';
      const data = await API.getCatalog();
      this.products = data.products || data || [];
      this.categories = data.categories || [];
      this.renderCategories();
      this.renderCatalog(this.filterProducts(search));
    } catch {
      this.catalogEl.innerHTML = '<div class="catalog-error">Не удалось загрузить каталог. Проверьте соединение с 1С.</div>';
    }
  },

  filterProducts(search) {
    let list = this.products;
    if (this.currentCategory) {
      list = list.filter(p => p.categoryId === this.currentCategory || p.category === this.currentCategory);
    }
    if (search) {
      const q = search.toLowerCase();
      list = list.filter(p => p.name.toLowerCase().includes(q) || (p.article || '').toLowerCase().includes(q));
    }
    return list;
  },

  renderCategories() {
    if (!this.categoriesEl || !this.categories.length) return;
    this.categoriesEl.innerHTML = `
      <button class="cat-btn ${!this.currentCategory ? 'active' : ''}" onclick="App.setCategory(null)">Все</button>
      ${this.categories.map(c => `
        <button class="cat-btn ${this.currentCategory === (c.id || c.name) ? 'active' : ''}" 
                onclick="App.setCategory('${c.id || c.name}')">${c.name}</button>
      `).join('')}
    `;
  },

  setCategory(id) {
    this.currentCategory = id;
    this.renderCategories();
    this.renderCatalog(this.filterProducts());
  },

  renderCatalog(products) {
    if (!products.length) {
      this.catalogEl.innerHTML = '<div class="catalog-empty">Товары не найдены</div>';
      return;
    }
    this.catalogEl.innerHTML = products.map(p => `
      <div class="product-card">
        <a href="/product.html?id=${p.id}" class="product-card-link">
          <div class="product-card-img">
            <img src="${p.image || 'img/no-image.svg'}" alt="${p.name}" loading="lazy">
          </div>
          <div class="product-card-body">
            ${p.article ? `<div class="product-card-article">${p.article}</div>` : ''}
            <div class="product-card-name">${p.name}</div>
            <div class="product-card-price">${(p.price || 0).toLocaleString()} ₽</div>
          </div>
        </a>
        <button class="product-card-btn" onclick="Cart.add({id:'${p.id}',name:'${p.name.replace(/'/g, "\\'")}',price:${p.price},image:'${p.image || ''}'})">
          В корзину
        </button>
      </div>
    `).join('');
  },

  navigate(page) {
    document.querySelectorAll('.page').forEach(p => p.classList.remove('page--active'));
    document.querySelectorAll('[data-page]').forEach(l => l.classList.remove('nav--active'));
    const target = document.getElementById(`page-${page}`);
    if (target) target.classList.add('page--active');
    const navLink = document.querySelector(`[data-page="${page}"]`);
    if (navLink) navLink.classList.add('nav--active');
    if (page === 'catalog') this.loadCatalog();
  },
};

document.addEventListener('DOMContentLoaded', () => App.init());
