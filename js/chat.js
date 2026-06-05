const Chat = {
  init() {
    this.btn = document.getElementById('chat-btn');
    this.window = document.getElementById('chat-window');
    this.messages = document.getElementById('chat-messages');
    this.input = document.getElementById('chat-input');
    this.sendBtn = document.getElementById('chat-send');
    if (!this.btn || !this.window) return;

    this.btn.addEventListener('click', () => this.toggle());
    this.sendBtn.addEventListener('click', () => this.send());
    this.input.addEventListener('keydown', e => { if (e.key === 'Enter') this.send(); });

    this.addMessage('assistant', 'Здравствуйте! Я виртуальный помощник. Задайте вопрос о товарах или напишите "менеджер", чтобы позвать сотрудника.');
  },

  toggle() {
    this.window.classList.toggle('open');
    if (this.window.classList.contains('open')) {
      this.input.focus();
    }
  },

  async send() {
    const text = this.input.value.trim();
    if (!text) return;
    this.input.value = '';
    this.addMessage('user', text);
    this.showTyping();

    const needManager = /менеджер|оператор|человек|позови/i.test(text);

    try {
      if (needManager) {
        await API.sendChatMessage(text, 'manager');
        this.addMessage('assistant', 'Передал ваш вопрос менеджеру. Он ответит вам в ближайшее время.');
      } else {
        const resp = await API.askAI(text);
        this.addMessage('assistant', resp.answer || resp.text || 'Не удалось получить ответ.');
      }
    } catch {
      this.addMessage('assistant', 'Не могу соединиться с сервером. Если вопрос срочный, напишите "менеджер".');
    } finally {
      this.hideTyping();
    }
  },

  addMessage(role, text) {
    const div = document.createElement('div');
    div.className = `chat-msg chat-msg--${role}`;
    div.textContent = text;
    this.messages.appendChild(div);
    this.messages.scrollTop = this.messages.scrollHeight;
  },

  showTyping() {
    const div = document.createElement('div');
    div.className = 'chat-msg chat-msg--assistant chat-typing';
    div.id = 'chat-typing';
    div.textContent = '...';
    this.messages.appendChild(div);
    this.messages.scrollTop = this.messages.scrollHeight;
  },

  hideTyping() {
    const el = document.getElementById('chat-typing');
    if (el) el.remove();
  },
};

document.addEventListener('DOMContentLoaded', () => Chat.init());
