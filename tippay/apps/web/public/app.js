// ===== Fliq Web App =====
// Auto-detect: if served from backend (/app/), use same origin. Otherwise localhost.
const API = location.port === '5173'
  ? 'http://localhost:3000'
  : location.origin;

let token = null;
let user = null;
let providerProfile = null;
let tipState = { providerId: null, provider: null, amount: 10000, rating: 5 };

// ===== Routing =====
function goTo(page) {
  document.querySelectorAll('.page').forEach(p => { p.style.display = 'none'; p.classList.add('hidden'); });
  const el = document.getElementById(`${page}-page`);
  if (el) { el.style.display = ''; el.classList.remove('hidden'); }
}

function demoCust() {
  document.getElementById('demo-tip-input').classList.remove('hidden');
  document.getElementById('demo-provider-id').focus();
}

function goTipPage() {
  const id = document.getElementById('demo-provider-id').value.trim();
  if (!id) return toast('Enter a provider ID');
  openTipPage(id);
}

// Check URL hash for direct tip links: #tip/PROVIDER_ID
function checkRoute() {
  const hash = location.hash;
  if (hash.startsWith('#tip/')) {
    const pid = hash.replace('#tip/', '');
    if (pid) { openTipPage(pid); return; }
  }
  // Check for saved session
  const saved = localStorage.getItem('tp_token');
  if (saved) {
    token = saved;
    user = JSON.parse(localStorage.getItem('tp_user') || '{}');
    goTo('dashboard');
    loadDashboard();
    return;
  }
  goTo('landing');
}

// ===== API =====
async function api(method, path, body, auth = true) {
  const h = { 'Content-Type': 'application/json' };
  if (auth && token) h['Authorization'] = `Bearer ${token}`;
  const opts = { method, headers: h };
  if (body) opts.body = JSON.stringify(body);
  const r = await fetch(API + path, opts);
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(d.message || `Error ${r.status}`);
  return d;
}

// ===== TIP PAGE (no login needed) =====
async function openTipPage(providerId) {
  tipState.providerId = providerId;
  goTo('tip');

  // Reset
  document.getElementById('tip-amount-section').classList.remove('hidden');
  document.getElementById('tip-success').classList.remove('hidden');
  document.getElementById('tip-success').classList.add('hidden');
  document.getElementById('tip-error').classList.add('hidden');

  try {
    const p = await api('GET', `/providers/${providerId}/public`, null, false);
    tipState.provider = p;

    const name = p.name || 'Service Provider';
    document.getElementById('tip-provider-avatar').textContent = name[0].toUpperCase();
    document.getElementById('tip-provider-name').textContent = name;
    document.getElementById('tip-provider-category').textContent = p.category || 'SERVICE';

    // Trust signal
    document.getElementById('trust-name').textContent = name.split(' ')[0];
    document.getElementById('net-name').textContent = name.split(' ')[0];

    const rating = p.ratingAverage ? Number(p.ratingAverage) : 0;
    const stars = Math.round(rating);
    document.getElementById('tip-provider-rating').innerHTML = rating > 0
      ? `<span class="star-display">${'★'.repeat(stars)}${'☆'.repeat(5 - stars)}</span> ${rating.toFixed(1)}`
      : '<span class="muted">New provider</span>';

    pickAmount(10000);
  } catch (e) {
    document.getElementById('tip-provider-name').textContent = 'Provider not found';
    document.getElementById('tip-amount-section').classList.add('hidden');
    showTipError(e.message);
  }
}

function pickAmount(paise) {
  tipState.amount = paise;
  document.getElementById('custom-amount').value = '';
  document.querySelectorAll('.preset').forEach(b => {
    const v = parseInt(b.dataset.amt || b.getAttribute('onclick').match(/\d+/)[0]);
    b.classList.toggle('active', v === paise);
  });
  updateBreakdown();
}

function setMsg(msg) {
  document.getElementById('tip-message').value = msg;
  document.querySelectorAll('.qmsg').forEach(b => {
    b.classList.toggle('selected', b.textContent.trim() === msg.trim() ||
      b.getAttribute('onclick').includes(msg));
  });
}

function customAmountChanged() {
  const v = parseInt(document.getElementById('custom-amount').value) || 0;
  if (v > 0) {
    tipState.amount = v * 100;
    document.querySelectorAll('.preset').forEach(b => b.classList.remove('active'));
    updateBreakdown();
  }
}

function updateBreakdown() {
  const p = tipState.amount;
  const r = p / 100;
  let comm = 0;
  if (p > 10000) comm = Math.round(p * 0.05);
  const net = p - comm;

  document.getElementById('bd-amount').textContent = `\u20B9${r.toFixed(0)}`;
  document.getElementById('bd-commission').textContent = `\u20B9${(comm / 100).toFixed(0)}`;
  const cr = document.getElementById('bd-commission-row');
  cr.style.display = comm > 0 ? 'flex' : 'none';
  cr.classList.toggle('hidden', comm === 0);
  document.getElementById('bd-net').textContent = `\u20B9${(net / 100).toFixed(0)}`;
  document.getElementById('pay-label').textContent = r.toFixed(0);
}

function rate(v) {
  tipState.rating = v;
  document.querySelectorAll('.stars-row .star').forEach(s => {
    s.classList.toggle('active', parseInt(s.dataset.v) <= v);
  });
}

async function payTip() {
  const btn = document.getElementById('pay-btn');
  btn.disabled = true;
  btn.textContent = 'Processing...';
  hideTipError();

  try {
    const body = {
      providerId: tipState.providerId,
      amountPaise: tipState.amount,
      source: 'QR_CODE',
      rating: tipState.rating,
      message: document.getElementById('tip-message').value.trim() || undefined,
    };

    const d = await api('POST', '/tips', body, false);

    const provName = tipState.provider?.name?.split(' ')[0] || 'their';
    document.getElementById('success-name').textContent = `${provName}'s`;
    document.getElementById('success-amount').textContent = `\u20B9${(d.amount / 100).toFixed(0)}`;
    document.getElementById('r-amount').textContent = `\u20B9${(d.amount / 100).toFixed(0)}`;
    document.getElementById('r-tipid').textContent = d.tipId?.substring(0, 12) + '...';
    document.getElementById('tip-amount-section').classList.add('hidden');
    document.getElementById('tip-success').classList.remove('hidden');
  } catch (e) {
    showTipError(e.message);
  } finally {
    btn.disabled = false;
    btn.innerHTML = `Pay \u20B9<span id="pay-label">${(tipState.amount / 100).toFixed(0)}</span> via UPI`;
  }
}

function resetTip() {
  document.getElementById('tip-amount-section').classList.remove('hidden');
  document.getElementById('tip-success').classList.add('hidden');
  document.getElementById('tip-message').value = '';
  pickAmount(10000);
  rate(5);
}

function showTipError(msg) { const e = document.getElementById('tip-error'); e.textContent = msg; e.classList.remove('hidden'); }
function hideTipError() { document.getElementById('tip-error').classList.add('hidden'); }

// ===== PROVIDER AUTH =====
let authPhone = '';

async function sendOtp() {
  const ph = document.getElementById('phone').value.trim();
  if (!/^[6-9]\d{9}$/.test(ph)) return showAuthErr('Enter a valid 10-digit number starting with 6-9');

  authPhone = `+91${ph}`;
  const btn = document.querySelector('#phone-step .auth-btn');
  btn.disabled = true; btn.textContent = 'Sending...';

  try {
    await api('POST', '/auth/otp/send', { phone: authPhone }, false);
    document.getElementById('phone-step').classList.add('hidden');
    document.getElementById('otp-step').classList.remove('hidden');
    document.getElementById('otp-sub').textContent = `OTP sent to ${authPhone}`;
    document.querySelector('.otp-box[data-i="0"]').focus();

    // Dev hint
    const hint = document.getElementById('otp-dev-hint');
    hint.textContent = 'Dev mode — check the database or ask Claude for the OTP';
    hint.classList.remove('hidden');

    hideAuthErr();
  } catch (e) {
    showAuthErr(e.message);
  } finally {
    btn.disabled = false; btn.textContent = 'Send OTP';
  }
}

async function verifyOtp() {
  const boxes = document.querySelectorAll('.otp-box');
  const code = Array.from(boxes).map(b => b.value).join('');
  if (code.length !== 6) return showAuthErr('Enter the full 6-digit OTP');

  const btn = document.querySelector('#otp-step .auth-btn');
  btn.disabled = true; btn.textContent = 'Verifying...';

  try {
    const d = await api('POST', '/auth/otp/verify', { phone: authPhone, code }, false);
    token = d.accessToken;
    user = d.user;
    localStorage.setItem('tp_token', token);
    localStorage.setItem('tp_refresh', d.refreshToken);
    localStorage.setItem('tp_user', JSON.stringify(user));

    goTo('dashboard');
    loadDashboard();
    toast('Welcome!');
  } catch (e) {
    showAuthErr(e.message);
  } finally {
    btn.disabled = false; btn.textContent = 'Verify';
  }
}

function showPhoneStep() {
  document.getElementById('phone-step').classList.remove('hidden');
  document.getElementById('otp-step').classList.add('hidden');
  hideAuthErr();
}

function showAuthErr(m) { const e = document.getElementById('auth-error'); e.textContent = m; e.classList.remove('hidden'); }
function hideAuthErr() { document.getElementById('auth-error').classList.add('hidden'); }

function logout() {
  token = null; user = null; providerProfile = null;
  localStorage.removeItem('tp_token');
  localStorage.removeItem('tp_refresh');
  localStorage.removeItem('tp_user');
  goTo('landing');
  // Reset auth forms
  document.getElementById('phone-step').classList.remove('hidden');
  document.getElementById('otp-step').classList.add('hidden');
  document.getElementById('phone').value = '';
  document.querySelectorAll('.otp-box').forEach(b => b.value = '');
}

// ===== DASHBOARD =====
async function loadDashboard() {
  document.getElementById('dash-phone').textContent = user?.phone || '';

  try {
    const p = await api('GET', '/providers/profile');
    providerProfile = p;
    document.getElementById('onboarding').classList.add('hidden');
    document.getElementById('dashboard').classList.remove('hidden');

    document.getElementById('d-tips').textContent = p.totalTipsReceived || 0;
    document.getElementById('d-rating').textContent = p.ratingAverage ? Number(p.ratingAverage).toFixed(1) : 'N/A';
    document.getElementById('d-category').textContent = p.category || '-';

    // Tip link
    document.getElementById('tip-link').textContent = `${location.origin}#tip/${p.id}`;

    loadQrCodes();
    loadProviderTips();
    loadPayouts();
  } catch (e) {
    // No provider profile yet — show onboarding
    document.getElementById('onboarding').classList.remove('hidden');
    document.getElementById('dashboard').classList.add('hidden');
  }
}

async function createProfile() {
  const cat = document.getElementById('cat-select').value;
  if (!cat) return toast('Pick a category');
  try {
    await api('POST', '/providers/profile', { category: cat });
    toast('Profile created!');
    loadDashboard();
  } catch (e) { toast('Error: ' + e.message); }
}

async function loadQrCodes() {
  const grid = document.getElementById('qr-grid');
  try {
    const d = await api('GET', '/qrcodes/my');
    const codes = Array.isArray(d) ? d : (d.qrCodes || []);
    if (codes.length === 0) { grid.innerHTML = '<p class="muted">No QR codes yet</p>'; return; }
    grid.innerHTML = codes.map(q => `
      <div class="qr-card">
        <div class="qr-visual">&#9638;</div>
        <div class="qr-label">${q.locationLabel || 'QR Code'}</div>
        <div class="qr-scans">${q.scanCount || 0} scans</div>
      </div>
    `).join('');
  } catch (e) { grid.innerHTML = '<p class="muted">Could not load</p>'; }
}

async function newQr() {
  const label = prompt('Location label (e.g. "Counter A", "Table 5"):');
  if (!label) return;
  try {
    await api('POST', '/qrcodes', { locationLabel: label });
    toast('QR code created!');
    loadQrCodes();
  } catch (e) { toast('Error: ' + e.message); }
}

async function loadProviderTips() {
  const list = document.getElementById('d-tips-list');
  try {
    const d = await api('GET', '/tips/provider');
    const tips = d.tips || [];
    if (tips.length === 0) { list.innerHTML = '<p class="muted">No tips received yet. Share your QR code!</p>'; return; }
    list.innerHTML = tips.slice(0, 10).map(t => {
      const date = new Date(t.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
      const stars = t.rating ? '★'.repeat(t.rating) : '';
      return `
        <div class="tip-item">
          <div class="tip-icon">&#8595;</div>
          <div class="tip-details">
            <div class="tip-msg">${t.message || 'Tip received'}</div>
            <div class="tip-date">${date} ${stars ? `<span class="tip-stars">${stars}</span>` : ''}</div>
          </div>
          <div class="tip-amt">+\u20B9${((t.amountPaise || 0) / 100).toFixed(0)}</div>
        </div>
      `;
    }).join('');
  } catch (e) { list.innerHTML = '<p class="muted">Could not load</p>'; }
}

async function requestPayout() {
  const r = parseInt(document.getElementById('payout-amt').value);
  if (!r || r < 100) return toast('Minimum payout \u20B9100');
  try {
    await api('POST', '/payouts/request', { amountPaise: r * 100 });
    toast('Payout requested!');
    document.getElementById('payout-amt').value = '';
    loadPayouts();
  } catch (e) { toast('Error: ' + e.message); }
}

async function loadPayouts() {
  const list = document.getElementById('d-payouts');
  try {
    const d = await api('GET', '/payouts/history');
    const payouts = Array.isArray(d) ? d : (d.payouts || []);
    if (payouts.length === 0) { list.innerHTML = '<p class="muted">No payouts yet</p>'; return; }
    list.innerHTML = payouts.map(p => {
      const date = new Date(p.createdAt).toLocaleDateString('en-IN');
      const st = (p.status || 'PENDING').toLowerCase();
      return `
        <div class="payout-item">
          <div>
            <div class="payout-amt">\u20B9${((p.amountPaise || 0) / 100).toFixed(0)}</div>
            <div class="payout-date">${date}</div>
          </div>
          <span class="payout-badge ${st}">${p.status}</span>
        </div>
      `;
    }).join('');
  } catch (e) { list.innerHTML = '<p class="muted">Could not load</p>'; }
}

// ===== Toast =====
function toast(msg) {
  const t = document.getElementById('toast');
  document.getElementById('toast-msg').textContent = msg;
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 3000);
}

// ===== OTP Box Navigation =====
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.otp-box').forEach((box, i, all) => {
    box.addEventListener('input', () => { if (box.value && i < 5) all[i + 1].focus(); });
    box.addEventListener('keydown', e => { if (e.key === 'Backspace' && !box.value && i > 0) all[i - 1].focus(); });
    box.addEventListener('paste', e => {
      e.preventDefault();
      const txt = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
      txt.split('').forEach((c, j) => { if (all[j]) all[j].value = c; });
    });
  });

  document.getElementById('phone').addEventListener('keydown', e => { if (e.key === 'Enter') sendOtp(); });
  document.getElementById('demo-provider-id').addEventListener('keydown', e => { if (e.key === 'Enter') goTipPage(); });

  checkRoute();
});

window.addEventListener('hashchange', checkRoute);
