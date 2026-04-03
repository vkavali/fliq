// ===== Fliq Web App =====
// Auto-detect: if served from backend (/app/), use same origin. Otherwise localhost.
const API = location.port === '5173'
  ? 'http://localhost:3000'
  : location.origin;

let token = null;
let user = null;
let providerProfile = null;
let pendingRedirect = null;
let tipState = { providerId: null, provider: null, amount: 10000, rating: 5 };

// ===== Routing =====
function goTo(page) {
  document.querySelectorAll('.page').forEach(p => { p.style.display = 'none'; p.classList.add('hidden'); });
  const el = document.getElementById(`${page}-page`);
  if (el) {
    const isFlex = page === 'landing' || page === 'login' || page === 'business-login' || page === 'tip' || page === 'app-home';
    el.style.display = isFlex ? 'flex' : 'block';
    el.classList.remove('hidden');
  }
  // Close modals on navigation
  document.getElementById('invite-modal')?.classList.add('hidden');
  // Load tipper demo data when navigating to it
  if (page === 'tipper-demo') loadTipperDemo();
  // Reset business login form when navigating to it
  if (page === 'business-login') resetBizLoginForm();
  // Reset provider login form when navigating to it
  if (page === 'login') { showPhoneStep(); hideAuthErr(); }
  // Init tipper portal OTP boxes
  if (page === 'tipper-portal') initTipperPortalOtp();
}

function demoCust() {
  const el = document.getElementById('demo-tip-input');
  el.classList.toggle('hidden');
  if (!el.classList.contains('hidden')) document.getElementById('demo-provider-id').focus();
}

function scrollToSection(id) {
  const el = document.getElementById(id);
  if (el) el.scrollIntoView({ behavior: 'smooth' });
}

async function goTipPage() {
  const code = document.getElementById('demo-provider-id').value.trim();
  const errEl = document.getElementById('demo-tip-error');
  const btn = document.getElementById('tip-now-btn');
  errEl.classList.add('hidden');

  if (!code) { errEl.textContent = 'Enter a provider code or ID'; errEl.classList.remove('hidden'); return; }

  btn.disabled = true; btn.textContent = 'Checking...';
  try {
    const provider = await resolveProvider(code);
    openTipPage(code, provider);
  } catch (e) {
    errEl.textContent = 'Invalid code — provider not found';
    errEl.classList.remove('hidden');
  } finally {
    btn.disabled = false; btn.textContent = 'Tip Now';
  }
}

async function resolveProvider(code) {
  try {
    const p = await api('GET', `/payment-links/${code}/resolve`, null, false);
    return {
      id: p.providerId, name: p.providerName || 'Service Provider',
      role: p.role, workplace: p.workplace, avatarUrl: p.avatarUrl, bio: p.bio,
      category: p.category, ratingAverage: p.ratingAverage, suggestedAmountPaise: p.suggestedAmountPaise,
    };
  } catch {
    const p = await api('GET', `/providers/${code}/public`, null, false);
    return {
      id: code, name: p.displayName || p.name || 'Service Provider',
      avatarUrl: p.avatarUrl, bio: p.bio,
      category: p.category, ratingAverage: p.ratingAverage,
    };
  }
}

// Check URL hash for direct tip links: #tip/PROVIDER_ID
function checkRoute() {
  const hash = location.hash;
  if (hash.startsWith('#tip/')) {
    const pid = hash.replace('#tip/', '');
    if (pid) { openTipPage(pid); return; }
  }
  if (hash === '#my-tips' || hash === '#tipper-portal') {
    goTo('tipper-portal');
    return;
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
  // Native app or installed PWA → skip landing page, go to login
  const isNativeApp = (window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform());
  const isInstalledPWA = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  if (isNativeApp || isInstalledPWA) {
    goTo('app-home');
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
  // Auto-refresh token on 401 (expired JWT)
  if (r.status === 401 && auth && token) {
    const refreshed = await tryRefreshToken();
    if (refreshed) {
      h['Authorization'] = `Bearer ${token}`;
      const r2 = await fetch(API + path, { ...opts, headers: h });
      const d2 = await r2.json().catch(() => ({}));
      if (!r2.ok) throw new Error(d2.message || `Error ${r2.status}`);
      return d2;
    }
    // Refresh failed — clear session and redirect to login
    logout();
    throw new Error('Session expired — please log in again');
  }
  if (!r.ok) throw new Error(d.message || `Error ${r.status}`);
  return d;
}

async function tryRefreshToken() {
  const refresh = localStorage.getItem('tp_refresh');
  if (!refresh) return false;
  try {
    const r = await fetch(API + '/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: refresh }),
    });
    if (!r.ok) return false;
    const d = await r.json();
    token = d.accessToken;
    localStorage.setItem('tp_token', token);
    return true;
  } catch { return false; }
}

// ===== TIP PAGE (no login needed) =====
async function openTipPage(code, provider) {
  // If no provider data passed, resolve it first (e.g. from hash route)
  if (!provider) {
    try {
      provider = await resolveProvider(code);
    } catch {
      toast('Invalid code — provider not found');
      goTo('landing');
      return;
    }
  }

  tipState.providerId = provider.id;
  tipState.provider = provider;
  goTo('tip');

  // Reset
  document.getElementById('tip-amount-section').classList.remove('hidden');
  document.getElementById('tip-success').classList.add('hidden');
  document.getElementById('tip-error').classList.add('hidden');

  const name = provider.name;
  const avatarEl = document.getElementById('tip-provider-avatar');
  if (provider.avatarUrl) {
    avatarEl.innerHTML = `<img src="${provider.avatarUrl}" alt="${name}" style="width:100%;height:100%;border-radius:50%;object-fit:cover;">`;
  } else {
    avatarEl.textContent = name[0].toUpperCase();
  }
  document.getElementById('tip-provider-name').textContent = name;

  // Show "Role at Workplace" subtitle or category badge
  const subtitleEl = document.getElementById('tip-provider-subtitle');
  if (subtitleEl) {
    if (provider.role && provider.workplace) {
      subtitleEl.textContent = `${provider.role} at ${provider.workplace}`;
      subtitleEl.classList.remove('hidden');
      document.getElementById('tip-provider-category').classList.add('hidden');
    } else if (provider.role) {
      subtitleEl.textContent = provider.role;
      subtitleEl.classList.remove('hidden');
      document.getElementById('tip-provider-category').classList.add('hidden');
    } else {
      subtitleEl.classList.add('hidden');
      document.getElementById('tip-provider-category').classList.remove('hidden');
    }
  }
  document.getElementById('tip-provider-category').textContent = provider.category || 'SERVICE';

  // Trust signal
  document.getElementById('trust-name').textContent = name.split(' ')[0];
  document.getElementById('net-name').textContent = name.split(' ')[0];

  const rating = provider.ratingAverage ? Number(provider.ratingAverage) : 0;
  const stars = Math.round(rating);
  document.getElementById('tip-provider-rating').innerHTML = rating > 0
    ? `<span class="star-display">${'★'.repeat(stars)}${'☆'.repeat(5 - stars)}</span> ${rating.toFixed(1)}`
    : '<span class="muted">New provider</span>';

  pickAmount(provider.suggestedAmountPaise || 10000);
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
    const res = await api('POST', '/auth/otp/send', { phone: authPhone }, false);
    document.getElementById('phone-step').classList.add('hidden');
    document.getElementById('otp-step').classList.remove('hidden');
    document.getElementById('otp-sub').textContent = `OTP sent to ${authPhone}`;

    // Dev mode: auto-fill OTP from response
    const hint = document.getElementById('otp-dev-hint');
    if (res.otp) {
      const boxes = document.querySelectorAll('.otp-box');
      res.otp.split('').forEach((c, i) => { if (boxes[i]) boxes[i].value = c; });
      hint.textContent = `Dev mode — OTP auto-filled: ${res.otp}`;
      hint.classList.remove('hidden');
    } else {
      document.querySelector('.otp-box[data-i="0"]').focus();
      hint.textContent = 'Check your phone for the OTP';
      hint.classList.remove('hidden');
    }

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

    if (pendingRedirect === 'business') {
      pendingRedirect = null;
      goToBusiness();
    } else {
      goTo('dashboard');
      loadDashboard();
    }
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
  pendingRedirect = null;
  localStorage.removeItem('tp_token');
  localStorage.removeItem('tp_refresh');
  localStorage.removeItem('tp_user');
  // Reset auth forms
  document.getElementById('phone-step').classList.remove('hidden');
  document.getElementById('otp-step').classList.add('hidden');
  document.getElementById('phone').value = '';
  document.querySelectorAll('#login-page .otp-box').forEach(b => b.value = '');
  resetBizLoginForm();
  goTo('landing');
}

// ===== DASHBOARD =====
async function loadDashboard() {
  document.getElementById('dash-phone').textContent = user?.phone || '';

  try {
    const p = await api('GET', '/providers/profile');
    providerProfile = p;
    document.getElementById('onboarding').classList.add('hidden');
    document.getElementById('dashboard').classList.remove('hidden');

    // Welcome header
    const name = p.displayName || p.user?.name || 'Provider';
    document.getElementById('d-provider-name').textContent = name;
    document.getElementById('d-avatar-letter').textContent = name.charAt(0).toUpperCase();
    document.getElementById('d-category').textContent = p.category || '-';
    if (p.createdAt) {
      const d = new Date(p.createdAt);
      document.getElementById('d-member-since').textContent = `Member since ${d.toLocaleDateString('en-IN', { month: 'short', year: 'numeric' })}`;
    }

    // Stats
    document.getElementById('d-tips').textContent = p.totalTipsReceived || 0;
    document.getElementById('d-rating').textContent = p.ratingAverage ? Number(p.ratingAverage).toFixed(1) : 'N/A';

    // Wallet balance
    try {
      const wallet = await api('GET', '/wallets/balance');
      document.getElementById('d-wallet-balance').textContent = wallet.balancePaise ? Math.round(wallet.balancePaise / 100) : '0';
    } catch (e) {
      document.getElementById('d-wallet-balance').textContent = '0';
    }

    // Tip link
    document.getElementById('tip-link').textContent = `${location.origin}/app/#tip/${p.id}`;

    loadQrCodes();
    loadTipLinks();
    loadProviderTips();
    loadPayouts();

    // V5: Load dream, reputation, intents, recurring, responses
    loadDream(p.id);
    loadReputation(p.id);
    loadIntents(p.id);
    loadRecurringTips();
    loadWorkerResponses(p.id);

    // Business affiliation + invitations
    loadAffiliation();
    loadInvitations();
  } catch (e) {
    // No provider profile yet — show onboarding
    document.getElementById('onboarding').classList.remove('hidden');
    document.getElementById('dashboard').classList.add('hidden');
  }
}

function copyTipLink() {
  const link = document.getElementById('tip-link').textContent;
  navigator.clipboard.writeText(link).then(() => toast('✅ Tip link copied!')).catch(() => toast('Failed to copy'));
}

// ===== Business Affiliation & Invitations =====
async function loadAffiliation() {
  try {
    const biz = await api('GET', '/business/mine');
    if (biz && biz.name) {
      const el = document.getElementById('provider-biz-affiliation');
      el.classList.remove('hidden');
      const BIZ_EMOJIS = { RESTAURANT: '🍽️', HOTEL: '🏨', SALON: '💇', RETAIL: '🛒', HEALTHCARE: '🏥', OTHER: '🏢' };
      document.getElementById('affiliation-emoji').textContent = BIZ_EMOJIS[biz.type] || '🏢';
      document.getElementById('affiliation-text').textContent = `Works at ${biz.name}`;
      // Find current user's role from members
      const myMember = (biz.members || []).find(m => m.providerId === user?.id);
      document.getElementById('affiliation-role').textContent = myMember ? myMember.role : 'Staff Member';
    }
  } catch (e) {
    // Not affiliated with any business — that's fine
  }
}

async function loadInvitations() {
  try {
    const invitations = await api('GET', '/business/invitations/mine');
    if (!invitations || invitations.length === 0) return;

    const container = document.getElementById('provider-invitations');
    const list = document.getElementById('invitations-list');
    container.classList.remove('hidden');

    list.innerHTML = invitations.map(inv => `
      <div style="background:white;border-radius:12px;padding:16px;margin-bottom:10px;border:1px solid #E9ECEF;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;">
        <div>
          <div style="font-size:14px;font-weight:700;color:#2D3436;">${inv.business?.name || 'Business'}</div>
          <div style="font-size:12px;color:#636E72;">Invited as <strong>${inv.role}</strong> · Expires ${new Date(inv.expiresAt).toLocaleDateString()}</div>
        </div>
        <div style="display:flex;gap:8px;">
          <button onclick="respondInvitation('${inv.id}', 'ACCEPT')" style="background:#00B894;color:white;border:none;padding:8px 16px;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer;">✓ Accept</button>
          <button onclick="respondInvitation('${inv.id}', 'DECLINE')" style="background:#E9ECEF;color:#636E72;border:none;padding:8px 16px;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer;">✗ Decline</button>
        </div>
      </div>
    `).join('');
  } catch (e) {
    // No invitations endpoint or error — ignore
  }
}

async function respondInvitation(invitationId, response) {
  try {
    await api('POST', `/business/invitations/${invitationId}/respond`, { response });
    toast(response === 'ACCEPT' ? '✅ Invitation accepted!' : 'Invitation declined');
    loadInvitations();
    if (response === 'ACCEPT') loadAffiliation();
  } catch (e) {
    toast('Failed: ' + (e.message || 'Error'));
  }
}

// ===== V5: DREAMS =====
async function loadDream(providerId) {
  try {
    const dreams = await api('GET', '/dreams');
    const active = dreams.find(d => d.status === 'ACTIVE') || dreams[0];
    if (active) {
      document.getElementById('dream-empty').classList.add('hidden');
      document.getElementById('dream-active').classList.remove('hidden');
      document.getElementById('dream-edit-btn').classList.remove('hidden');
      document.getElementById('d-dream-title').textContent = active.title;
      document.getElementById('d-dream-desc').textContent = active.description || '';
      const pct = active.goalAmountPaise > 0 ? Math.round((active.currentAmountPaise / active.goalAmountPaise) * 100) : 0;
      setTimeout(() => { document.getElementById('d-dream-fill').style.width = pct + '%'; }, 300);
      document.getElementById('d-dream-pct').textContent = pct + '%';
      document.getElementById('d-dream-amounts').textContent = `₹${Math.round(active.currentAmountPaise / 100)} / ₹${Math.round(active.goalAmountPaise / 100)}`;
    } else {
      document.getElementById('dream-empty').classList.remove('hidden');
      document.getElementById('dream-active').classList.add('hidden');
      document.getElementById('dream-edit-btn').classList.add('hidden');
    }
  } catch (e) {
    // Dreams API may not exist yet, show empty state
    document.getElementById('dream-empty').classList.remove('hidden');
    document.getElementById('dream-edit-btn').classList.add('hidden');
  }
}

function showDreamForm() {
  document.getElementById('dream-form').classList.remove('hidden');
  document.getElementById('dream-display').classList.add('hidden');
  document.getElementById('dream-edit-btn').classList.add('hidden');
}

function hideDreamForm() {
  document.getElementById('dream-form').classList.add('hidden');
  document.getElementById('dream-display').classList.remove('hidden');
  document.getElementById('dream-edit-btn').classList.remove('hidden');
}

async function saveDream() {
  const title = document.getElementById('dream-title-input').value.trim();
  const description = document.getElementById('dream-desc-input').value.trim();
  const goalAmount = parseInt(document.getElementById('dream-goal-input').value) || 0;
  if (!title || goalAmount < 100) { showToast('Enter a title and goal amount (min ₹100)'); return; }
  try {
    await api('POST', '/dreams', { title, description, goalAmountPaise: goalAmount * 100 });
    hideDreamForm();
    loadDream(providerProfile?.id);
    showToast('Dream saved! Tippers will see this.');
  } catch (e) {
    showToast(e.message || 'Failed to save dream');
  }
}

// ===== V5: REPUTATION =====
async function loadReputation(providerId) {
  try {
    const rep = await api('GET', `/reputation/${providerId}`);
    const score = Math.round(rep.score || 0);
    document.getElementById('d-reputation').textContent = score + '/100';
    document.getElementById('d-rep-circle').textContent = score;
    if (score >= 80) {
      document.getElementById('d-rep-detail').textContent = '⭐ Excellent — top-tier trust';
    } else if (score >= 50) {
      document.getElementById('d-rep-detail').textContent = '📈 Growing — keep it up!';
    } else {
      document.getElementById('d-rep-detail').textContent = 'Receive more tips to build trust';
    }
  } catch (e) {
    document.getElementById('d-reputation').textContent = 'New';
    document.getElementById('d-rep-circle').textContent = '—';
  }
}

// ===== V5: INTENT BREAKDOWN =====
async function loadIntents(providerId) {
  try {
    const tips = await api('GET', '/tips/received?limit=100');
    const counts = { KINDNESS: 0, SPEED: 0, EXPERIENCE: 0, SUPPORT: 0 };
    (tips.data || tips || []).forEach(t => {
      if (t.intent && counts[t.intent] !== undefined) counts[t.intent]++;
    });
    document.getElementById('d-intent-kindness').textContent = counts.KINDNESS + ' kindness';
    document.getElementById('d-intent-speed').textContent = counts.SPEED + ' speed';
    document.getElementById('d-intent-experience').textContent = counts.EXPERIENCE + ' experience';
    document.getElementById('d-intent-support').textContent = counts.SUPPORT + ' support';
  } catch (e) {
    // Intent data not available yet
  }
}

// ===== V5: RECURRING TIPS (AutoPay Subscribers) =====
async function loadRecurringTips() {
  try {
    const subs = await api('GET', '/recurring-tips/provider');
    const list = document.getElementById('d-recurring-list');
    if (!subs || subs.length === 0) {
      list.innerHTML = '<div style="text-align:center;padding:24px;color:#B2BEC3;"><div style="font-size:28px;margin-bottom:6px;">🔄</div><p style="font-size:13px;">No subscribers yet. Share your tip link to get recurring support!</p></div>';
      return;
    }
    list.innerHTML = subs.map(s => {
      const amt = (Number(s.amountPaise) / 100).toFixed(0);
      const freq = s.frequency === 'MONTHLY' ? 'month' : 'week';
      const statusColor = s.status === 'ACTIVE' ? '#00B894' : s.status === 'PAUSED' ? '#FDCB6E' : '#E17055';
      const next = s.nextChargeDate ? new Date(s.nextChargeDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) : '-';
      return `
        <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 0;border-bottom:1px solid #F0F0F0;">
          <div style="display:flex;align-items:center;gap:12px;">
            <div style="width:36px;height:36px;background:linear-gradient(135deg,#E8FFF8,#C6F6E9);border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:16px;">🔄</div>
            <div>
              <div style="font-weight:600;font-size:14px;">₹${amt}/${freq}</div>
              <div style="font-size:11px;color:#636E72;">Next: ${next} · ${s.totalCharges || 0} charges</div>
            </div>
          </div>
          <span style="font-size:11px;font-weight:600;color:${statusColor};">● ${s.status}</span>
        </div>`;
    }).join('');
  } catch (e) {
    // Recurring tips API not available
  }
}

// ===== V5: WORKER RESPONSES (Thank-you loop) =====
async function loadWorkerResponses(providerId) {
  try {
    const tips = await api('GET', '/tips/received?limit=5');
    const list = document.getElementById('d-responses-list');
    const tipsArr = tips.data || tips || [];
    const unreplied = tipsArr.filter(t => t.status === 'PAID' || t.status === 'SETTLED');

    if (unreplied.length === 0) {
      list.innerHTML = '<div style="text-align:center;padding:24px;color:#B2BEC3;"><div style="font-size:28px;margin-bottom:6px;">💬</div><p style="font-size:13px;">No pending tips to respond to.</p></div>';
      return;
    }
    list.innerHTML = unreplied.map(t => {
      const amt = (Number(t.amountPaise || t.netAmountPaise) / 100).toFixed(0);
      const intentLabel = t.intent ? { KINDNESS: '🤗', SPEED: '⚡', EXPERIENCE: '✨', SUPPORT: '💪' }[t.intent] || '' : '';
      const msg = t.message ? `"${t.message}"` : '';
      return `
        <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 0;border-bottom:1px solid #F0F0F0;">
          <div>
            <div style="font-weight:600;font-size:14px;">₹${amt} tip ${intentLabel} ${msg ? `<span style="font-size:12px;color:#636E72;">${msg}</span>` : ''}</div>
            <div style="font-size:11px;color:#636E72;">${t.rating ? '★'.repeat(t.rating) + '☆'.repeat(5 - t.rating) : 'No rating'}</div>
          </div>
          <div style="display:flex;gap:6px;">
            <button onclick="sendResponse('${t.id}','🙏')" style="background:#F0EDFF;border:none;border-radius:8px;padding:6px 10px;cursor:pointer;font-size:16px;" title="Thank you">🙏</button>
            <button onclick="sendResponse('${t.id}','❤️')" style="background:#FFEDE9;border:none;border-radius:8px;padding:6px 10px;cursor:pointer;font-size:16px;" title="Love">❤️</button>
            <button onclick="sendResponse('${t.id}','😊')" style="background:#E8FFF8;border:none;border-radius:8px;padding:6px 10px;cursor:pointer;font-size:16px;" title="Happy">😊</button>
          </div>
        </div>`;
    }).join('');
  } catch (e) {
    // Worker responses not available
  }
}

async function sendResponse(tipId, emoji) {
  try {
    await api('POST', `/tips/${tipId}/respond`, { type: 'emoji', emoji });
    showToast('Thank-you sent! ' + emoji);
    loadWorkerResponses(providerProfile?.id);
  } catch (e) {
    showToast('Response sent! ' + emoji); // Mock success
  }
}

function previewAvatar(input) {
  const file = input.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = (e) => {
    const img = document.getElementById('avatar-preview');
    img.src = e.target.result;
    img.classList.remove('hidden');
    document.getElementById('avatar-placeholder').classList.add('hidden');
  };
  reader.readAsDataURL(file);
}

async function uploadAvatar(file) {
  const formData = new FormData();
  formData.append('avatar', file);
  const h = {};
  if (token) h['Authorization'] = `Bearer ${token}`;
  const r = await fetch(API + '/providers/profile/avatar', { method: 'POST', headers: h, body: formData });
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(d.message || 'Avatar upload failed');
  return d;
}

async function createProfile() {
  const name = document.getElementById('name-input').value.trim();
  const cat = document.getElementById('cat-select').value;
  const bio = document.getElementById('bio-input').value.trim();
  if (!name) return toast('Enter your name');
  if (!cat) return toast('Pick a category');
  try {
    await api('POST', '/providers/profile', { displayName: name, category: cat, bio: bio || undefined });
    // Upload avatar if selected
    const avatarFile = document.getElementById('avatar-input').files[0];
    if (avatarFile) {
      try { await uploadAvatar(avatarFile); } catch (e) { toast('Profile created, but avatar upload failed: ' + e.message); }
    }
    toast('Profile created!');
    loadDashboard();
  } catch (e) { toast('Error: ' + e.message); }
}

async function createTipLink() {
  const role = document.getElementById('link-role').value.trim();
  const workplace = document.getElementById('link-workplace').value.trim();
  try {
    const result = await api('POST', '/payment-links', { role: role || undefined, workplace: workplace || undefined });
    toast('Tip link created!');
    document.getElementById('link-role').value = '';
    document.getElementById('link-workplace').value = '';
    loadTipLinks();
  } catch (e) { toast('Error: ' + e.message); }
}

async function loadTipLinks() {
  const list = document.getElementById('tip-links-list');
  try {
    const links = await api('GET', '/payment-links/my');
    const items = Array.isArray(links) ? links : [];
    if (items.length === 0) { list.innerHTML = '<p class="muted">No tip links yet. Create one above!</p>'; return; }
    list.innerHTML = items.map(l => {
      const subtitle = [l.role, l.workplace].filter(Boolean).join(' at ');
      return `
        <div class="tip-link-card">
          <div class="tip-link-info">
            <div class="tip-link-title">${subtitle || 'Tip Link'}</div>
            <div class="tip-link-url">${l.shareableUrl}</div>
            <div class="tip-link-stats">${l.clickCount || 0} clicks</div>
          </div>
          <button class="small-btn" onclick="navigator.clipboard.writeText('${l.shareableUrl}');toast('Copied!')">Copy</button>
        </div>`;
    }).join('');
  } catch (e) { list.innerHTML = '<p class="muted">Could not load tip links</p>'; }
}

async function loadQrCodes() {
  const grid = document.getElementById('qr-grid');
  try {
    const d = await api('GET', '/qrcodes/my');
    const codes = Array.isArray(d) ? d : (d.qrCodes || []);
    if (codes.length === 0) { grid.innerHTML = '<p class="muted">No QR codes yet. Click "+ New QR" to create one.</p>'; return; }
    const tipBase = `${location.origin}/app/#tip/${providerProfile.id}`;
    grid.innerHTML = codes.map(q => {
      const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(tipBase)}`;
      return `
      <div class="qr-card">
        <img src="${qrUrl}" alt="QR Code" style="width:120px;height:120px;border-radius:8px;">
        <div class="qr-label">${q.locationLabel || 'QR Code'}</div>
        <div class="qr-scans">${q.scanCount || 0} scans</div>
      </div>`;
    }).join('');
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

// ===== BUSINESS (B2B) MODULE =====

let bizState = { business: null, businessId: null };

const BIZ_TYPE_EMOJIS = {
  HOTEL: '🏨', SALON: '💇', RESTAURANT: '🍽️',
  SPA: '🧖', CAFE: '☕', RETAIL: '🛍️', OTHER: '🏢',
};

let authBizEmail = '';

async function goToBusiness() {
  if (!token) {
    pendingRedirect = 'business';
    goTo('business-login');
    toast('Please login with your business email');
    return;
  }
  document.getElementById('biz-phone').textContent = user?.email || user?.phone || '';
  goTo('business');
  try {
    const biz = await api('GET', '/business/mine');
    bizState.business = biz;
    bizState.businessId = biz.id;
    showBizDashboard(biz);
  } catch (e) {
    // No business yet — show registration
    document.getElementById('biz-register-section').classList.remove('hidden');
    document.getElementById('biz-dashboard-section').classList.add('hidden');
  }
}

async function sendBizOtp() {
  const email = document.getElementById('biz-email').value.trim();
  if (!email || !email.includes('@')) return showAuthErr('Enter a valid email address');

  authBizEmail = email;
  const btn = document.querySelector('#biz-email-step button');
  btn.disabled = true; btn.textContent = 'Sending...';

  try {
    const res = await api('POST', '/auth/otp/email/send', { email: authBizEmail }, false);
    document.getElementById('biz-email-step').classList.add('hidden');
    document.getElementById('biz-otp-step').classList.remove('hidden');
    document.getElementById('biz-otp-sub').textContent = `Access code sent to ${authBizEmail}`;

    if (res.otp) {
      const boxes = document.querySelectorAll('#biz-otp-row .otp-box');
      res.otp.split('').forEach((c, i) => { if (boxes[i]) boxes[i].value = c; });
    } else {
      document.querySelector('#biz-otp-row .otp-box[data-i="0"]').focus();
    }
    hideAuthErr();
  } catch (e) {
    showAuthErr(e.message);
  } finally {
    btn.disabled = false; btn.textContent = 'Get Access Code';
  }
}

async function verifyBizOtp() {
  const boxes = document.querySelectorAll('#biz-otp-row .otp-box');
  const code = Array.from(boxes).map(b => b.value).join('');
  if (code.length !== 6) return showAuthErr('Enter the full 6-digit code');

  const btn = document.querySelector('#biz-otp-step button');
  btn.disabled = true; btn.textContent = 'Verifying...';

  try {
    const d = await api('POST', '/auth/otp/email/verify', { email: authBizEmail, code }, false);
    token = d.accessToken;
    user = d.user;
    localStorage.setItem('tp_token', token);
    localStorage.setItem('tp_refresh', d.refreshToken);
    localStorage.setItem('tp_user', JSON.stringify(user));

    goToBusiness();
    toast('Business Login Successful');
  } catch (e) {
    showAuthErr(e.message);
  } finally {
    btn.disabled = false; btn.textContent = 'Access Dashboard';
  }
}

function showBizEmailStep() {
  document.getElementById('biz-otp-step').classList.add('hidden');
  document.getElementById('biz-email-step').classList.remove('hidden');
  hideAuthErr();
}

function resetBizLoginForm() {
  document.getElementById('biz-email-step')?.classList.remove('hidden');
  document.getElementById('biz-otp-step')?.classList.add('hidden');
  const emailInput = document.getElementById('biz-email');
  if (emailInput) emailInput.value = '';
  document.querySelectorAll('#biz-otp-row .otp-box').forEach(b => b.value = '');
  document.getElementById('biz-auth-error')?.classList.add('hidden');
}

async function registerBusiness(e) {
  e.preventDefault();
  const btn = document.getElementById('biz-register-btn');
  const errEl = document.getElementById('biz-register-error');
  errEl.classList.add('hidden');
  btn.disabled = true; btn.textContent = 'Registering...';

  const name = document.getElementById('biz-name').value.trim();
  const type = document.getElementById('biz-type').value;
  const address = document.getElementById('biz-address').value.trim();
  const contactPhone = document.getElementById('biz-contact-phone').value.trim();
  const contactEmail = document.getElementById('biz-contact-email').value.trim();
  const gstin = document.getElementById('biz-gstin').value.trim().toUpperCase();

  const payload = { name, type };
  if (address) payload.address = address;
  if (contactPhone) payload.contactPhone = contactPhone;
  if (contactEmail) payload.contactEmail = contactEmail;
  if (gstin) payload.gstin = gstin;

  try {
    const biz = await api('POST', '/business/register', payload);
    bizState.business = biz;
    bizState.businessId = biz.id;
    toast('Business registered!');
    showBizDashboard(biz);
  } catch (err) {
    errEl.textContent = err.message;
    errEl.classList.remove('hidden');
  } finally {
    btn.disabled = false; btn.textContent = 'Register Business';
  }
}

async function showBizDashboard(biz) {
  document.getElementById('biz-register-section').classList.add('hidden');
  document.getElementById('biz-dashboard-section').classList.remove('hidden');

  const emoji = BIZ_TYPE_EMOJIS[biz.type] || '🏢';
  document.getElementById('biz-type-emoji').textContent = emoji;
  document.getElementById('biz-header-name').textContent = biz.name;
  document.getElementById('biz-header-meta').textContent =
    [biz.type, biz.address].filter(Boolean).join(' • ');

  loadBizStats(biz.id);
  bizTab('staff');
}

async function loadBizStats(bizId) {
  try {
    const stats = await api('GET', `/business/${bizId}/dashboard`);
    const fmtRs = (paise) => '₹' + (paise / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 });
    document.getElementById('stat-total-tips').textContent = fmtRs(stats.totalAmountPaise || 0);
    document.getElementById('stat-tip-count').textContent = stats.totalTipsCount || 0;
    document.getElementById('stat-avg-rating').textContent =
      stats.averageRating ? Number(stats.averageRating).toFixed(1) + ' ★' : 'N/A';
    document.getElementById('stat-staff-count').textContent = stats.staffCount || 0;
  } catch (e) { /* non-fatal */ }
}

function loadSettingsTab() {
  // Load user profile
  document.getElementById('settings-name').value = user?.name || '';
  document.getElementById('settings-email').value = user?.email || '';
  document.getElementById('settings-phone').value = user?.phone || '';
  // Load business details
  const biz = bizState.business;
  if (biz) {
    document.getElementById('settings-biz-name').value = biz.name || '';
    document.getElementById('settings-biz-type').value = biz.type || '';
    document.getElementById('settings-biz-address').value = biz.address || '';
  }
}

async function saveProfile() {
  const btn = document.getElementById('settings-save-btn');
  const msg = document.getElementById('settings-msg');
  btn.disabled = true; btn.textContent = 'Saving...';
  msg.classList.add('hidden');

  const name = document.getElementById('settings-name').value.trim();
  const phone = document.getElementById('settings-phone').value.trim();

  const payload = {};
  if (name) payload.name = name;
  if (phone) payload.phone = phone;

  try {
    const updated = await api('PATCH', '/users/me', payload);
    user = { ...user, ...updated };
    localStorage.setItem('tp_user', JSON.stringify(user));
    document.getElementById('biz-phone').textContent = user.email || user.phone || '';
    msg.textContent = '✅ Profile updated';
    msg.style.background = 'var(--green-bg)';
    msg.style.color = 'var(--green)';
    msg.classList.remove('hidden');
    toast('Profile saved');
  } catch (e) {
    msg.textContent = '❌ ' + (e.message || 'Failed to save');
    msg.style.background = '#FFF0F0';
    msg.style.color = '#E17055';
    msg.classList.remove('hidden');
  } finally {
    btn.disabled = false; btn.textContent = 'Save Changes';
  }
}

function bizTab(tab) {
  document.querySelectorAll('.biz-tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.biz-tab-content').forEach(t => t.classList.add('hidden'));

  const idx = { staff: 0, pools: 1, satisfaction: 2, qrcodes: 3, settings: 4 }[tab] ?? 0;
  document.querySelectorAll('.biz-tab')[idx]?.classList.add('active');
  document.getElementById(`biz-tab-${tab}`)?.classList.remove('hidden');

  if (tab === 'staff') loadBizStaff();
  else if (tab === 'pools') loadPools();
  else if (tab === 'satisfaction') loadBizSatisfaction();
  else if (tab === 'qrcodes') loadBizQrCodes();
  else if (tab === 'settings') loadSettingsTab();
}

async function loadBizStaff() {
  const wrap = document.getElementById('biz-staff-table-wrap');
  wrap.innerHTML = '<div class="biz-loading">Loading...</div>';
  try {
    const staff = await api('GET', `/business/${bizState.businessId}/staff`);
    if (!staff.length) {
      wrap.innerHTML = '<p class="biz-muted">No staff yet. Invite team members to get started.</p>';
      return;
    }
    const fmtRs = (paise) => '₹' + (paise / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 });
    const rows = staff.map(m => {
      const p = m.provider || {};
      const prof = p.providerProfile || {};
      const name = prof.displayName || p.name || (p.email ? p.email.split('@')[0] : 'Staff Member');
      const contact = p.phone ? p.phone.replace(/(\d{6})(\d{4})$/, '••••••$2') : (p.email || '');
      const tips = m.tips || {};
      const rating = tips.averageRating ? Number(tips.averageRating).toFixed(1) : '—';
      const roleColor = { ADMIN: '#e53935', MANAGER: '#1565c0', STAFF: '#555' }[m.role] || '#555';
      return `
        <tr>
          <td>
            <div class="staff-name-cell">
              <div class="staff-avatar">${name[0]?.toUpperCase() || '?'}</div>
              <div>
                <strong>${name}</strong>
                <div class="staff-phone">${contact}</div>
              </div>
            </div>
          </td>
          <td><span class="role-badge" style="color:${roleColor};border-color:${roleColor}">${m.role}</span></td>
          <td>${fmtRs(tips.totalAmountPaise || 0)}</td>
          <td>${tips.count || 0}</td>
          <td>${rating} ${tips.averageRating ? '★' : ''}</td>
          <td>
            <button class="biz-danger-btn" onclick="removeMember('${m.memberId}', '${name}')">Remove</button>
          </td>
        </tr>`;
    }).join('');
    wrap.innerHTML = `
      <table class="biz-table">
        <thead><tr>
          <th>Staff Member</th><th>Role</th><th>Total Tips</th><th>Transactions</th><th>Rating</th><th></th>
        </tr></thead>
        <tbody>${rows}</tbody>
      </table>`;
  } catch (e) {
    wrap.innerHTML = `<p class="error-box">${e.message}</p>`;
  }
}

async function removeMember(memberId, name) {
  if (!confirm(`Remove ${name} from your business?`)) return;
  try {
    await api('DELETE', `/business/${bizState.businessId}/members/${memberId}`);
    toast(`${name} removed`);
    loadBizStaff();
    loadBizStats(bizState.businessId);
  } catch (e) { toast('Error: ' + e.message); }
}

async function loadBizSatisfaction() {
  const distEl = document.getElementById('biz-rating-dist');
  const listEl = document.getElementById('biz-reviews-list');
  distEl.innerHTML = '<div class="biz-loading">Loading...</div>';
  listEl.innerHTML = '';
  try {
    const data = await api('GET', `/business/${bizState.businessId}/satisfaction`);
    const dist = data.ratingDistribution || [];
    const max = Math.max(...dist.map(d => d.count), 1);
    distEl.innerHTML = `
      <div class="rating-dist-wrap">
        ${dist.reverse().map(d => `
          <div class="rating-row">
            <span class="rating-star">${d.star} ★</span>
            <div class="rating-bar-bg">
              <div class="rating-bar" style="width:${(d.count / max * 100).toFixed(0)}%"></div>
            </div>
            <span class="rating-count">${d.count}</span>
          </div>`).join('')}
      </div>`;

    const reviews = (data.tips || []).filter(t => t.message || t.rating);
    if (!reviews.length) {
      listEl.innerHTML = '<p class="biz-muted">No reviews yet.</p>';
      return;
    }
    listEl.innerHTML = `
      <h4 style="margin:16px 0 8px">Recent Feedback</h4>
      ${reviews.slice(0, 50).map(t => {
        const pname = t.provider?.providerProfile?.displayName || t.provider?.name || 'Staff';
        const stars = t.rating ? '★'.repeat(t.rating) + '☆'.repeat(5 - t.rating) : '';
        return `
          <div class="review-card">
            <div class="review-header">
              <span class="review-staff">${pname}</span>
              <span class="review-stars">${stars}</span>
              <span class="review-date">${new Date(t.createdAt).toLocaleDateString('en-IN')}</span>
            </div>
            ${t.message ? `<p class="review-message">"${t.message}"</p>` : ''}
          </div>`;
      }).join('')}`;
  } catch (e) {
    distEl.innerHTML = `<p class="error-box">${e.message}</p>`;
  }
}

async function loadBizQrCodes() {
  const grid = document.getElementById('biz-qr-grid');
  grid.innerHTML = '<div class="biz-loading">Loading QR codes...</div>';
  try {
    const staff = await api('GET', `/business/${bizState.businessId}/qrcodes`);
    if (!staff.length) {
      grid.innerHTML = '<p class="biz-muted">No staff QR codes yet. Staff members can generate QR codes from their provider dashboard.</p>';
      return;
    }
    grid.innerHTML = staff.map(m => {
      const name = m.displayName || 'Staff';
      const qrs = m.qrCodes || [];
      const qrCards = qrs.length
        ? qrs.map(q => `
            <div class="qr-standee" data-name="${name}" data-qr="${q.qrImageUrl || ''}">
              <div class="qr-standee-inner">
                <div class="qr-standee-header">
                  <img src="logo-full.png" alt="Fliq" class="qr-standee-logo">
                </div>
                ${q.qrImageUrl
                  ? `<img src="${q.qrImageUrl}" alt="QR" class="qr-standee-img">`
                  : `<div class="qr-standee-placeholder">📷 QR</div>`}
                <div class="qr-standee-name">${name}</div>
                ${q.locationLabel ? `<div class="qr-standee-label">${q.locationLabel}</div>` : ''}
                <div class="qr-standee-tagline">Scan to tip via UPI</div>
              </div>
            </div>`).join('')
        : `<p class="biz-muted" style="font-size:12px">No QR codes yet</p>`;
      return `
        <div class="qr-staff-group">
          <div class="qr-staff-name">${name}</div>
          <div class="qr-standees-row">${qrCards}</div>
        </div>`;
    }).join('');
  } catch (e) {
    grid.innerHTML = `<p class="error-box">${e.message}</p>`;
  }
}

function printAllQr() {
  const printArea = document.getElementById('print-area');
  const standees = document.querySelectorAll('.qr-standee');
  if (!standees.length) { toast('No QR codes to print'); return; }
  printArea.innerHTML = Array.from(standees).map(s => s.outerHTML).join('');
  window.print();
}

function showInviteModal() {
  document.getElementById('invite-modal').classList.remove('hidden');
  document.getElementById('invite-phone').value = '';
  document.getElementById('invite-error').classList.add('hidden');
}

function closeInviteModal() {
  document.getElementById('invite-modal').classList.add('hidden');
}

async function sendInvite() {
  const phone = document.getElementById('invite-phone').value.trim();
  const role = document.getElementById('invite-role').value;
  const errEl = document.getElementById('invite-error');
  errEl.classList.add('hidden');
  if (!phone) { errEl.textContent = 'Enter phone number'; errEl.classList.remove('hidden'); return; }
  try {
    await api('POST', `/business/${bizState.businessId}/invite`, { phone, role });
    toast('Invitation sent to ' + phone);
    closeInviteModal();
    loadBizStaff();
  } catch (e) {
    errEl.textContent = e.message;
    errEl.classList.remove('hidden');
  }
}

async function exportCsv() {
  const a = document.createElement('a');
  a.href = `${API}/business/${bizState.businessId}/export`;
  // Pass auth header via URL param is not ideal; open in new tab (requires backend to accept query param or use cookie)
  // For now, fetch and download
  try {
    const h = { 'Authorization': `Bearer ${token}` };
    const r = await fetch(`${API}/business/${bizState.businessId}/export`, { headers: h });
    if (!r.ok) throw new Error('Export failed');
    const blob = await r.blob();
    const url = URL.createObjectURL(blob);
    a.href = url;
    a.download = 'fliq-business-tips.csv';
    a.click();
    URL.revokeObjectURL(url);
  } catch (e) { toast('Export failed: ' + e.message); }
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
  // Scope OTP auto-tab per row so provider and business OTP boxes don't interfere
  document.querySelectorAll('.otp-row, #otp-step').forEach(row => {
    const boxes = row.querySelectorAll('.otp-box');
    boxes.forEach((box, i) => {
      box.addEventListener('input', () => { if (box.value && i < boxes.length - 1) boxes[i + 1].focus(); });
      box.addEventListener('keydown', e => { if (e.key === 'Backspace' && !box.value && i > 0) boxes[i - 1].focus(); });
      box.addEventListener('paste', e => {
        e.preventDefault();
        const txt = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
        txt.split('').forEach((c, j) => { if (boxes[j]) boxes[j].value = c; });
        if (txt.length >= boxes.length) boxes[boxes.length - 1].focus();
      });
    });
  });

  document.getElementById('phone')?.addEventListener('keydown', e => { if (e.key === 'Enter') sendOtp(); });
  document.getElementById('biz-email')?.addEventListener('keydown', e => { if (e.key === 'Enter') sendBizOtp(); });

  checkRoute();
});

window.addEventListener('hashchange', checkRoute);

// ===== TIPPER DEMO (TESTING ONLY — REMOVE FOR PROD) =====
let tipperDemoLoaded = false;

async function loadTipperDemo() {
  if (tipperDemoLoaded) return;
  tipperDemoLoaded = true;
  const grid = document.getElementById('demo-providers');
  grid.innerHTML = '<div style="text-align:center;padding:20px;color:#B2BEC3;">Loading providers...</div>';

  try {
    // Try dev status endpoint for test accounts
    const status = await fetch(API + '/dev/status').then(r => {
      if (!r.ok) throw new Error('Dev bypass not enabled');
      return r.json();
    }).catch(() => null);
    let providers = [];

    if (status && status.testWorker) {
      // /dev/status returns testWorker with id, name, paymentLinks
      const w = status.testWorker;
      let pub = null;
      try { pub = await fetch(API + `/providers/${w.id}/public`).then(r => r.ok ? r.json() : null); } catch (e) {}
      providers.push({
        id: w.id,
        displayName: pub?.displayName || w.name || 'Test Worker',
        category: pub?.category || 'RESTAURANT',
        ratingAverage: pub?.ratingAverage,
        paymentLinkCodes: w.paymentLinks || [],
      });
    }

    if (providers.length === 0) {
      // Fallback: try common test short code from seed
      try {
        const pub = await fetch(API + '/payment-links/testwrkr/resolve').then(r => r.ok ? r.json() : null);
        if (pub) providers.push({
          id: pub.providerId, displayName: pub.providerName || 'Test Worker',
          category: pub.category || 'RESTAURANT', paymentLinkCodes: ['testwrkr'],
        });
      } catch (e) {}
    }

    // Also fetch payment links if logged in
    let paymentLinks = [];
    if (token) {
      try {
        paymentLinks = await api('GET', '/payment-links');
      } catch (e) {}
    }

    if (providers.length === 0 && paymentLinks.length === 0) {
      grid.innerHTML = `
        <div style="grid-column:1/-1;text-align:center;padding:40px;">
          <div style="font-size:40px;margin-bottom:12px;">🔍</div>
          <p style="font-weight:600;margin-bottom:8px;">No providers found</p>
          <p style="color:#636E72;font-size:13px;">Login as a provider first, create a profile, then come back here.</p>
          <p style="color:#636E72;font-size:13px;margin-top:8px;">Or enter a provider ID manually below.</p>
        </div>`;
      return;
    }

    let html = '';
    providers.forEach(p => {
      const name = p.displayName || p.name || 'Provider';
      const cat = p.category || 'SERVICE';
      const initial = name[0]?.toUpperCase() || '?';
      const rating = p.ratingAverage ? Number(p.ratingAverage).toFixed(1) : 'New';
      const linkCodes = p.paymentLinkCodes || [];
      const v5Code = linkCodes[0] || p.id; // prefer short code, fallback to ID
      html += `
        <div style="background:white;border-radius:16px;padding:20px;border:1px solid #E9ECEF;">
          <div style="display:flex;align-items:center;gap:14px;margin-bottom:16px;">
            <div style="width:48px;height:48px;background:linear-gradient(135deg,#6C5CE7,#A29BFE);border-radius:50%;display:flex;align-items:center;justify-content:center;color:white;font-size:20px;font-weight:800;">${initial}</div>
            <div style="flex:1;">
              <div style="font-weight:700;font-size:15px;">${name}</div>
              <div style="font-size:12px;color:#636E72;">${cat} · ⭐ ${rating}</div>
            </div>
          </div>
          <div style="font-size:11px;color:#B2BEC3;margin-bottom:4px;word-break:break-all;">ID: ${p.id}</div>
          ${linkCodes.length ? `<div style="font-size:11px;color:#6C5CE7;margin-bottom:12px;">Tip link: <code>${linkCodes.join(', ')}</code></div>` : '<div style="margin-bottom:12px;"></div>'}
          <div style="display:flex;gap:8px;">
            <button class="small-btn" onclick="openTipV5('${v5Code}')" style="background:#6C5CE7;color:white;flex:1;">V5 Tip Flow →</button>
            <button class="small-btn" onclick="openTipSPA('${p.id}')" style="flex:1;">SPA Tip</button>
          </div>
        </div>`;
    });

    // Show payment links too
    if (paymentLinks.length > 0) {
      paymentLinks.forEach(pl => {
        html += `
          <div style="background:white;border-radius:16px;padding:20px;border:1px solid #6C5CE744;transition:all 0.2s;">
            <div style="display:flex;align-items:center;gap:14px;margin-bottom:16px;">
              <div style="width:48px;height:48px;background:linear-gradient(135deg,#00B894,#55efc4);border-radius:50%;display:flex;align-items:center;justify-content:center;color:white;font-size:20px;">🔗</div>
              <div style="flex:1;">
                <div style="font-weight:700;font-size:15px;">Tip Link: ${pl.shortCode}</div>
                <div style="font-size:12px;color:#636E72;">${pl.role || ''} ${pl.workplace ? '@ ' + pl.workplace : ''}</div>
              </div>
            </div>
            <div style="font-size:11px;color:#B2BEC3;margin-bottom:12px;">Short code: <code>${pl.shortCode}</code></div>
            <button class="small-btn" onclick="openTipV5('${pl.shortCode}')" style="background:#00B894;color:white;width:100%;">Open V5 Tip Flow →</button>
          </div>`;
      });
    }

    grid.innerHTML = html;
  } catch (e) {
    grid.innerHTML = `<div style="grid-column:1/-1;text-align:center;padding:40px;color:#E17055;">Error loading providers: ${e.message}</div>`;
  }
}

function openTipV5(idOrCode) {
  if (!idOrCode) { showToast('Enter a provider ID or short code'); return; }
  // First try as payment link (short code), then as provider ID
  window.open(`/tip/${idOrCode}`, '_blank');
}

function openTipSPA(id) {
  if (!id) { showToast('Enter a provider ID'); return; }
  location.hash = `#tip/${id}`;
  checkRoute();
}

// ===== TIP POOLS =====
function showPoolForm() { document.getElementById('pool-form').classList.remove('hidden'); }
function hidePoolForm() { document.getElementById('pool-form').classList.add('hidden'); }

async function createPool() {
  const name = document.getElementById('pool-name').value.trim();
  const splitMethod = document.getElementById('pool-split').value;
  const description = document.getElementById('pool-desc').value.trim();
  if (!name) { showToast('Enter a pool name'); return; }
  try {
    await api('POST', '/tip-pools', { name, splitMethod, description });
    hidePoolForm();
    loadPools();
    showToast('Tip pool created!');
  } catch (e) {
    showToast(e.message || 'Failed to create pool');
  }
}

async function loadPools() {
  try {
    const pools = await api('GET', '/tip-pools/my');
    const list = document.getElementById('pools-list');
    if (!pools || pools.length === 0) {
      list.innerHTML = '<div style="text-align:center;padding:40px;color:#B2BEC3;"><div style="font-size:40px;margin-bottom:8px;">🫙</div><p style="font-weight:600;margin-bottom:4px;">No tip pools yet</p><p style="font-size:13px;">Create a pool to start splitting tips.</p></div>';
      return;
    }
    list.innerHTML = pools.map(p => `
      <div style="background:white;border-radius:12px;padding:16px;border:1px solid #E9ECEF;margin-bottom:10px;">
        <div style="display:flex;justify-content:space-between;align-items:center;">
          <div>
            <div style="font-weight:700;">${p.name}</div>
            <div style="font-size:12px;color:#636E72;">${p.splitMethod} split · ${p.members?.length || 0} members</div>
          </div>
          <span style="font-size:11px;color:${p.isActive ? '#00B894' : '#E17055'};font-weight:600;">● ${p.isActive ? 'Active' : 'Inactive'}</span>
        </div>
        ${p.description ? `<p style="font-size:12px;color:#636E72;margin-top:8px;">${p.description}</p>` : ''}
      </div>`).join('');
  } catch (e) {
    // Pools not available
  }
}

// ===== CORPORATE BUDGET (UPI Circle Concept) =====
let corpAllowances = [];

function addCorpAllowance() {
  const phone = document.getElementById('corp-emp-phone').value.trim();
  const limit = parseInt(document.getElementById('corp-emp-limit').value) || 0;
  if (!phone || limit < 100) { showToast('Enter phone and limit (min ₹100)'); return; }
  corpAllowances.push({ phone, limit, used: 0 });
  document.getElementById('corp-emp-phone').value = '';
  document.getElementById('corp-emp-limit').value = '';
  renderCorpAllowances();
  showToast('Employee allowance set');
}

function renderCorpAllowances() {
  const list = document.getElementById('corp-allowances-list');
  const total = corpAllowances.reduce((s, a) => s + a.limit, 0);
  const used = corpAllowances.reduce((s, a) => s + a.used, 0);
  document.getElementById('corp-budget-total').textContent = '₹' + total.toLocaleString('en-IN');
  document.getElementById('corp-budget-used').textContent = '₹' + used.toLocaleString('en-IN');
  document.getElementById('corp-budget-remaining').textContent = '₹' + (total - used).toLocaleString('en-IN');

  if (corpAllowances.length === 0) {
    list.innerHTML = '<h4 style="margin-bottom:12px;">Employee Tipping Allowances</h4><div style="text-align:center;padding:20px;color:#B2BEC3;"><p style="font-size:13px;">No employees added yet.</p></div>';
    return;
  }
  list.innerHTML = '<h4 style="margin-bottom:12px;">Employee Tipping Allowances</h4>' +
    corpAllowances.map((a, i) => `
      <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 0;border-bottom:1px solid #F0F0F0;">
        <div>
          <div style="font-weight:600;font-size:14px;">${a.phone}</div>
          <div style="font-size:12px;color:#636E72;">₹${a.used} used of ₹${a.limit}/month</div>
        </div>
        <div style="display:flex;gap:8px;align-items:center;">
          <div style="width:80px;height:6px;background:#E9ECEF;border-radius:3px;overflow:hidden;">
            <div style="height:100%;background:${a.used/a.limit > 0.8 ? '#E17055' : '#00B894'};width:${Math.min(100, (a.used/a.limit)*100)}%;border-radius:3px;"></div>
          </div>
          <button onclick="corpAllowances.splice(${i},1);renderCorpAllowances();" style="background:none;border:none;cursor:pointer;color:#E17055;font-size:14px;">✕</button>
        </div>
      </div>`).join('');
}

// ===== TIPPER PORTAL — Manage Subscriptions =====
let tipperToken = null;
let tipperUser = null;

function initTipperPortalOtp() {
  // Set up auto-tab for tipper OTP boxes
  document.querySelectorAll('.tipper-otp-box').forEach(box => {
    box.value = '';
    box.addEventListener('input', function () {
      if (this.value.length === 1) {
        const next = this.nextElementSibling;
        if (next && next.classList.contains('tipper-otp-box')) next.focus();
      }
    });
    box.addEventListener('keydown', function (e) {
      if (e.key === 'Backspace' && !this.value) {
        const prev = this.previousElementSibling;
        if (prev && prev.classList.contains('tipper-otp-box')) prev.focus();
      }
    });
  });
}

async function tipperSendOtp() {
  const phone = document.getElementById('tipper-phone-input').value.trim();
  const errEl = document.getElementById('tipper-auth-error');
  errEl.classList.add('hidden');

  if (!/^\d{10}$/.test(phone)) {
    errEl.textContent = 'Please enter a valid 10-digit phone number';
    errEl.classList.remove('hidden');
    return;
  }

  try {
    await api('POST', '/auth/otp/send', { phone: `+91${phone}` }, false);
    document.getElementById('tipper-phone-step').classList.add('hidden');
    document.getElementById('tipper-otp-step').classList.remove('hidden');
    document.querySelector('.tipper-otp-box')?.focus();
    toast('📱 OTP sent to +91' + phone);
  } catch (e) {
    errEl.textContent = e.message || 'Failed to send OTP';
    errEl.classList.remove('hidden');
  }
}

function tipperBackToPhone() {
  document.getElementById('tipper-otp-step').classList.add('hidden');
  document.getElementById('tipper-phone-step').classList.remove('hidden');
  document.getElementById('tipper-auth-error').classList.add('hidden');
}

async function tipperVerifyOtp() {
  const phone = document.getElementById('tipper-phone-input').value.trim();
  const boxes = document.querySelectorAll('.tipper-otp-box');
  const code = Array.from(boxes).map(b => b.value).join('');
  const errEl = document.getElementById('tipper-auth-error');
  errEl.classList.add('hidden');

  if (code.length !== 6) {
    errEl.textContent = 'Please enter all 6 digits';
    errEl.classList.remove('hidden');
    return;
  }

  try {
    const res = await api('POST', '/auth/otp/verify', { phone: `+91${phone}`, code }, false);
    tipperToken = res.accessToken || res.token;
    tipperUser = res.user || {};

    // Show dashboard, hide auth
    document.getElementById('tipper-auth-section').classList.add('hidden');
    document.getElementById('tipper-dashboard-section').classList.remove('hidden');
    document.getElementById('tipper-logout-btn').classList.remove('hidden');
    document.getElementById('tipper-phone-label').textContent = `📞 +91${phone}`;

    // Load data
    loadTipperSubscriptions();
    loadTipperHistory();
  } catch (e) {
    errEl.textContent = e.message || 'Invalid OTP. Please try again.';
    errEl.classList.remove('hidden');
  }
}

function tipperLogout() {
  tipperToken = null;
  tipperUser = null;
  document.getElementById('tipper-auth-section').classList.remove('hidden');
  document.getElementById('tipper-dashboard-section').classList.add('hidden');
  document.getElementById('tipper-logout-btn').classList.add('hidden');
  document.getElementById('tipper-phone-step').classList.remove('hidden');
  document.getElementById('tipper-otp-step').classList.add('hidden');
  document.getElementById('tipper-phone-input').value = '';
  document.querySelectorAll('.tipper-otp-box').forEach(b => b.value = '');
  toast('Logged out');
}

async function tipperApi(method, path, body) {
  const h = { 'Content-Type': 'application/json' };
  if (tipperToken) h['Authorization'] = `Bearer ${tipperToken}`;
  const opts = { method, headers: h };
  if (body) opts.body = JSON.stringify(body);
  const r = await fetch(API + path, opts);
  const d = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(d.message || `Error ${r.status}`);
  return d;
}

async function loadTipperSubscriptions() {
  const list = document.getElementById('tipper-subscriptions-list');
  const countEl = document.getElementById('tipper-sub-count');
  try {
    const subs = await tipperApi('GET', '/recurring-tips');
    if (!subs || subs.length === 0) {
      countEl.textContent = '0';
      list.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text2);"><div style="font-size:28px;margin-bottom:6px;">🔄</div><p style="font-size:13px;">No active subscriptions</p></div>';
      return;
    }

    const active = subs.filter(s => s.status === 'ACTIVE' || s.status === 'PAUSED');
    countEl.textContent = active.length;

    list.innerHTML = subs.map(s => {
      const amt = (Number(s.amountPaise) / 100).toFixed(0);
      const freq = s.frequency === 'MONTHLY' ? 'month' : 'week';
      const next = s.nextChargeDate ? new Date(s.nextChargeDate).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) : '-';
      const statusColors = { ACTIVE: '#00B894', PAUSED: '#FDCB6E', CANCELLED: '#E17055' };
      const statusColor = statusColors[s.status] || '#B2BEC3';
      const providerName = s.provider?.displayName || s.provider?.user?.name || 'Provider';

      let actions = '';
      if (s.status === 'ACTIVE') {
        actions = `
          <button onclick="tipperPauseSub('${s.id}')" style="background:#FFF3E0;color:#FF8F00;border:none;padding:6px 12px;border-radius:8px;font-size:11px;font-weight:600;cursor:pointer;">⏸ Pause</button>
          <button onclick="tipperCancelSub('${s.id}')" style="background:#FFEDE9;color:#E17055;border:none;padding:6px 12px;border-radius:8px;font-size:11px;font-weight:600;cursor:pointer;">✕ Cancel</button>`;
      } else if (s.status === 'PAUSED') {
        actions = `
          <button onclick="tipperResumeSub('${s.id}')" style="background:#E8FFF8;color:#00B894;border:none;padding:6px 12px;border-radius:8px;font-size:11px;font-weight:600;cursor:pointer;">▶ Resume</button>
          <button onclick="tipperCancelSub('${s.id}')" style="background:#FFEDE9;color:#E17055;border:none;padding:6px 12px;border-radius:8px;font-size:11px;font-weight:600;cursor:pointer;">✕ Cancel</button>`;
      } else {
        actions = `<span style="font-size:11px;color:#B2BEC3;">Ended</span>`;
      }

      return `
        <div style="padding:14px 0;border-bottom:1px solid var(--border);">
          <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
            <div>
              <div style="font-weight:700;font-size:14px;">₹${amt}/${freq} → ${providerName}</div>
              <div style="font-size:11px;color:var(--text2);">Next: ${next} · ${s.totalCharges || 0} charges</div>
            </div>
            <span style="font-size:11px;font-weight:700;color:${statusColor};">● ${s.status}</span>
          </div>
          <div style="display:flex;gap:6px;">${actions}</div>
        </div>`;
    }).join('');
  } catch (e) {
    list.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text2);"><p style="font-size:13px;">Could not load subscriptions</p></div>';
  }
}

async function tipperPauseSub(id) {
  if (!confirm('Pause this subscription? You can resume it anytime.')) return;
  try {
    await tipperApi('PATCH', `/recurring-tips/${id}/pause`);
    toast('⏸ Subscription paused');
    loadTipperSubscriptions();
  } catch (e) {
    toast('Failed to pause: ' + (e.message || 'Error'));
  }
}

async function tipperResumeSub(id) {
  try {
    await tipperApi('PATCH', `/recurring-tips/${id}/resume`);
    toast('▶ Subscription resumed');
    loadTipperSubscriptions();
  } catch (e) {
    toast('Failed to resume: ' + (e.message || 'Error'));
  }
}

async function tipperCancelSub(id) {
  if (!confirm('Cancel this subscription permanently? This cannot be undone.')) return;
  try {
    await tipperApi('DELETE', `/recurring-tips/${id}`);
    toast('✕ Subscription cancelled');
    loadTipperSubscriptions();
  } catch (e) {
    toast('Failed to cancel: ' + (e.message || 'Error'));
  }
}

async function loadTipperHistory() {
  const list = document.getElementById('tipper-tips-list');
  try {
    const result = await tipperApi('GET', '/tips/customer?limit=20');
    const tips = result.data || result || [];
    if (!tips || tips.length === 0) {
      list.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text2);"><div style="font-size:28px;margin-bottom:6px;">💰</div><p style="font-size:13px;">No tips sent yet</p></div>';
      return;
    }

    list.innerHTML = tips.map(t => {
      const amt = (Number(t.amountPaise || t.netAmountPaise) / 100).toFixed(0);
      const date = new Date(t.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
      const intentLabel = t.intent ? { KINDNESS: '🤗 Kindness', SPEED: '⚡ Speed', EXPERIENCE: '✨ Experience', SUPPORT: '💪 Support' }[t.intent] || '' : '';
      const providerName = t.provider?.displayName || t.provider?.user?.name || 'Provider';
      const statusBadge = t.status === 'PAID' || t.status === 'SETTLED' 
        ? '<span style="color:#00B894;font-size:11px;font-weight:600;">✓ Paid</span>' 
        : `<span style="color:#FDCB6E;font-size:11px;font-weight:600;">${t.status}</span>`;

      return `
        <div style="display:flex;align-items:center;justify-content:space-between;padding:12px 0;border-bottom:1px solid var(--border);">
          <div>
            <div style="font-weight:600;font-size:14px;">₹${amt} → ${providerName}</div>
            <div style="font-size:11px;color:var(--text2);">${date}${intentLabel ? ' · ' + intentLabel : ''}${t.message ? ' · "' + t.message + '"' : ''}</div>
          </div>
          ${statusBadge}
        </div>`;
    }).join('');
  } catch (e) {
    list.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text2);"><p style="font-size:13px;">Could not load tip history</p></div>';
  }
}
