'use strict';
const menuButton = document.getElementById('institutional-mobile-menu');
const mobileNavigation = document.getElementById('institutional-mobile-navigation');
function closeMenu() {
  if (!menuButton || !mobileNavigation) return;
  menuButton.setAttribute('aria-expanded', 'false');
  mobileNavigation.hidden = true;
  menuButton.classList.remove('burger--open');
  mobileNavigation.classList.remove('block-header-layout-mobile__dropdown--open');
}
menuButton?.addEventListener('click', () => {
  const open = menuButton.getAttribute('aria-expanded') !== 'true';
  menuButton.setAttribute('aria-expanded', String(open));
  mobileNavigation.hidden = !open;
  menuButton.classList.toggle('burger--open', open);
  mobileNavigation.classList.toggle('block-header-layout-mobile__dropdown--open', open);
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && menuButton?.getAttribute('aria-expanded') === 'true') {
    closeMenu();
    menuButton.focus();
  }
});
mobileNavigation?.addEventListener('click', event => {
  if (event.target.closest('a')) closeMenu();
});
const contactForm = document.getElementById('institutional-contact-form');
contactForm?.addEventListener('submit', event => {
  event.preventDefault();
  if (!contactForm.reportValidity()) return;
  const data = new FormData(contactForm);
  const body = `Nome: ${data.get('Name')}\nE-mail: ${data.get('Email')}\nTelefone: ${data.get('Phone')}\n\n${data.get('Message')}`;
  const recipient = contactForm.dataset.email;
  if (!recipient || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(recipient)) return;
  window.location.href = `mailto:${recipient}?subject=${encodeURIComponent('Atendimento corporativo — Royal Clean')}&body=${encodeURIComponent(body)}`;
  document.getElementById('institutional-contact-status').textContent =
    'Revise e envie a mensagem no seu aplicativo de e-mail. Se ele não abrir, utilize o endereço de atendimento exibido nesta página.';
});
const contactSubmit = contactForm?.querySelector('button[type="submit"]');
if (contactSubmit) contactSubmit.disabled = false;
