// ===== Fliq V5 Tip Flow =====
const API = location.origin;

const PRESETS_NORMAL = [
  { paise: 2000, label: 'Quick thanks' },
  { paise: 5000, label: 'Buy chai' },
  { paise: 10000, label: 'Great service', popular: true },
  { paise: 20000, label: 'Above & beyond' },
  { paise: 50000, label: 'Exceptional' },
  { paise: 100000, label: 'VIP' },
];
const PRESETS_SHAGUN = [
  { paise: 5100, label: '₹51 shagun' },
  { paise: 10100, label: '₹101 shagun', popular: true },
  { paise: 25100, label: '₹251 shagun' },
  { paise: 50100, label: '₹501 shagun' },
  { paise: 100100, label: '₹1001 shagun' },
  { paise: 200100, label: '₹2001 shagun' },
];

const INTENT_LABELS = {
  KINDNESS: 'with kindness 🤗',
  SPEED: 'for speed ⚡',
  EXPERIENCE: 'for the experience ✨',
  SUPPORT: 'to support 💪',
};

let state = {
  shortCode: null, providerId: null, provider: null, publicProfile: null,
  amount: 10000, rating: 5, intent: null, tipId: null, shagun: false,
  pollTimer: null, pollCount: 0,
  // Subscribe state
  subAmount: 10000, subFreq: 'MONTHLY',
};

// ===== Init =====
(async function init() {
  const parts = location.pathname.split('/').filter(Boolean);
  const code = parts[parts.length - 1];
  if (!code) { showFatalError('Invalid tip link'); return; }
  state.shortCode = code;
  console.log('[Fliq] Resolving code:', code);

  try {
    let resolved = false;

    // Try 1: Resolve as payment link short code
    try {
      console.log('[Fliq] Try 1: /payment-links/' + code + '/resolve');
      const data = await api('GET', `/payment-links/${code}/resolve`);
      console.log('[Fliq] Resolved as payment link:', data);
      state.providerId = data.providerId;
      state.provider = data;
      resolved = true;

      // Fetch enhanced public profile
      try {
        const pub = await api('GET', `/providers/${data.providerId}/public`);
        state.publicProfile = pub;
      } catch (e) { /* non-fatal */ }

      renderLanding(state.provider, state.publicProfile);
    } catch (e) {
      console.log('[Fliq] Not a payment link:', e.message);
    }

    // Try 2: Resolve as provider ID
    if (!resolved) {
      try {
        console.log('[Fliq] Try 2: /providers/' + code + '/public');
        const pub = await api('GET', `/providers/${code}/public`);
        console.log('[Fliq] Resolved as provider:', pub);
        state.providerId = code;
        state.publicProfile = pub;
        state.provider = {
          providerId: code,
          providerName: pub.displayName || pub.name,
          category: pub.category,
          ratingAverage: pub.ratingAverage,
          totalTipsReceived: pub.totalTipsReceived,
          avatarUrl: pub.avatarUrl,
        };
        renderLanding(state.provider, pub);
        resolved = true;
      } catch (e2) {
        console.log('[Fliq] Not a provider either:', e2.message);
      }
    }

    if (!resolved) {
      showFatalError('This tip link could not be found. It may have expired or been deactivated.');
      return;
    }

    document.getElementById('loading').classList.add('hidden');
    goScreen('landing');
  } catch (e) {
    console.error('[Fliq] Fatal error:', e);
    showFatalError(e.message || 'This tip link may have expired.');
  }
})();

// ===== API =====
async function api(method, path, body) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 10000); // 10s timeout
  try {
    const opts = { method, headers: { 'Content-Type': 'application/json' }, signal: controller.signal };
    if (body) opts.body = JSON.stringify(body);
    const r = await fetch(API + path, opts);
    const d = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(d.message || `Error ${r.status}`);
    return d;
  } catch (e) {
    if (e.name === 'AbortError') throw new Error('Request timed out — server may be restarting');
    throw e;
  } finally {
    clearTimeout(timeout);
  }
}

// ===== Screen Navigation =====
function goScreen(name) {
  ['landing', 'intent', 'amount', 'waiting', 'impact', 'subscribe', 'sub-success'].forEach(s => {
    const el = document.getElementById(`screen-${s}`);
    if (el) el.classList.add('hidden');
  });
  const target = document.getElementById(`screen-${name}`);
  if (target) target.classList.remove('hidden');

  if (name === 'amount') renderAmountGrid();
  if (name === 'subscribe') initSubscribeScreen();
}

// ===== Screen 1: Landing =====
function renderLanding(data, pub) {
  // Greeting
  const h = new Date().getHours();
  let greet = h < 12 ? '🙏 Good Morning' : h < 17 ? '🙏 Good Afternoon' : '🙏 Good Evening';
  document.getElementById('greeting').textContent = greet;

  // Provider info
  const name = data.providerName || pub?.name || 'Service Provider';
  const avatarEl = document.getElementById('avatar');
  const avatarUrl = data.avatarUrl || pub?.avatarUrl;
  if (avatarUrl) {
    avatarEl.innerHTML = `<img src="${avatarUrl}" alt="${name}">`;
  } else {
    avatarEl.textContent = name[0].toUpperCase();
  }
  document.getElementById('provider-name').textContent = name;
  document.getElementById('trust-name').textContent = name.split(' ')[0];
  document.getElementById('net-name').textContent = name.split(' ')[0];

  // Subtitle
  const sub = document.getElementById('provider-subtitle');
  if (data.role && data.workplace) {
    sub.textContent = `${data.role} at ${data.workplace}`;
    sub.classList.remove('hidden');
  } else if (data.role) {
    sub.textContent = data.role;
    sub.classList.remove('hidden');
  }

  document.getElementById('provider-category').textContent = data.category || pub?.category || 'SERVICE';

  // Rating
  const rating = pub?.ratingAverage ? Number(pub.ratingAverage) : (data.ratingAverage ? Number(data.ratingAverage) : 0);
  const stars = Math.round(rating);
  const ratingEl = document.getElementById('rating-row');
  const totalTips = pub?.totalTipsReceived || data.totalTipsReceived || 0;
  if (rating > 0) {
    ratingEl.innerHTML = `<span class="stars">${'★'.repeat(stars)}${'☆'.repeat(5 - stars)}</span> ${rating.toFixed(1)} · ${totalTips} tips`;
  } else {
    ratingEl.innerHTML = '<span style="color:var(--muted)">New provider</span>';
  }

  // Stats
  if (pub?.stats) {
    document.getElementById('stat-tips-today').textContent = pub.stats.tipsToday || 0;
    document.getElementById('stat-recent').textContent = pub.stats.recentAppreciations || 0;
  }
  document.getElementById('stat-total').textContent = totalTips;

  // Reputation
  if (pub?.reputation && pub.reputation.score > 0) {
    document.getElementById('rep-score').textContent = Math.round(pub.reputation.score);
    document.getElementById('rep-section').classList.remove('hidden');
  }

  // Subscribers
  const subCount = pub?.stats?.subscriberCount || pub?.subscriberCount || pub?.stats?.activeSubscribers || 0;
  const subEl = document.getElementById('subscribers-text');
  if (subCount > 0) {
    subEl.textContent = `🔄 ${subCount} subscriber${subCount === 1 ? '' : 's'}`;
    subEl.style.color = 'var(--green)';
    subEl.style.fontWeight = '600';
  } else {
    subEl.textContent = 'No subscribers yet — share your tip link to get started';
    subEl.style.color = 'var(--muted)';
    subEl.style.fontWeight = 'normal';
  }

  // Dream
  if (pub?.dream) {
    const d = pub.dream;
    document.getElementById('dream-title').textContent = d.title;
    document.getElementById('dream-desc').textContent = d.description || '';
    const pct = d.percentage || 0;
    setTimeout(() => { document.getElementById('dream-fill').style.width = pct + '%'; }, 300);
    document.getElementById('dream-pct').textContent = pct + '%';
    document.getElementById('dream-amounts').textContent = `₹${Math.round(d.currentAmount / 100)} / ₹${Math.round(d.goalAmount / 100)}`;
    document.getElementById('dream-section').classList.remove('hidden');
  }

  // Default amount
  if (data.suggestedAmountPaise && data.suggestedAmountPaise >= 1000) {
    state.amount = data.suggestedAmountPaise;
  }
}

// ===== Screen 2: Intent =====
function pickIntent(intent) {
  state.intent = intent;
  document.querySelectorAll('.intent-tile').forEach(t => {
    t.classList.toggle('active', t.dataset.intent === intent);
  });
  // Update button text
  document.getElementById('intent-next-btn').textContent = `Continue ${INTENT_LABELS[intent] || ''}`;
}

function skipIntent() {
  state.intent = null;
  goScreen('amount');
}

// ===== Screen 3: Amount =====
function renderAmountGrid() {
  const presets = state.shagun ? PRESETS_SHAGUN : PRESETS_NORMAL;
  const grid = document.getElementById('amount-grid');
  grid.innerHTML = presets.map(p => `
    <button class="amt-btn${p.paise === state.amount ? ' active' : ''}" onclick="pickAmt(${p.paise})" data-amt="${p.paise}">
      <span class="amount">₹${(p.paise / 100).toFixed(0)}</span>
      <span class="label">${p.label}</span>
      ${p.popular ? '<span class="popular-tag">Popular</span>' : ''}
    </button>`).join('');
  updateBreakdown();
  updatePayBtn();
}

function toggleShagun() {
  state.shagun = document.getElementById('shagun-toggle').checked;
  // Reset to first popular or first preset
  const presets = state.shagun ? PRESETS_SHAGUN : PRESETS_NORMAL;
  const popular = presets.find(p => p.popular) || presets[0];
  state.amount = popular.paise;
  renderAmountGrid();
}

function pickAmt(paise) {
  state.amount = paise;
  document.getElementById('custom-amount').value = '';
  document.querySelectorAll('.amt-btn').forEach(b => {
    b.classList.toggle('active', parseInt(b.dataset.amt) === paise);
  });
  updateBreakdown();
  updatePayBtn();
}

function onCustomAmount() {
  const v = parseInt(document.getElementById('custom-amount').value) || 0;
  if (v > 0) {
    state.amount = v * 100;
    document.querySelectorAll('.amt-btn').forEach(b => b.classList.remove('active'));
    updateBreakdown();
    updatePayBtn();
  }
}

function updateBreakdown() {
  const p = state.amount;
  const r = p / 100;
  let comm = 0;
  if (p > 10000) comm = Math.round(p * 0.05);
  const net = p - comm;
  document.getElementById('bd-amount').textContent = `₹${r.toFixed(0)}`;
  document.getElementById('bd-comm-val').textContent = `₹${(comm / 100).toFixed(0)}`;
  const cr = document.getElementById('bd-commission');
  cr.style.display = comm > 0 ? 'flex' : 'none';
  cr.classList.toggle('hidden', comm === 0);
  document.getElementById('bd-net').textContent = `₹${(net / 100).toFixed(0)}`;
}

function updatePayBtn() {
  const r = (state.amount / 100).toFixed(0);
  const intentSuffix = state.intent ? ` ${INTENT_LABELS[state.intent]}` : ' via UPI';
  document.getElementById('pay-amount').textContent = r;
  document.getElementById('pay-btn').innerHTML = `Tip ₹<span id="pay-amount">${r}</span>${intentSuffix}`;
}

function setRating(v) {
  state.rating = v;
  document.querySelectorAll('.star-btn').forEach(s => {
    s.classList.toggle('active', parseInt(s.dataset.v) <= v);
  });
}

function setMessage(msg) {
  document.getElementById('tip-message').value = msg;
  document.querySelectorAll('.chip').forEach(c => {
    c.classList.toggle('active', c.textContent.trim() === msg);
  });
}

// ===== Pay =====
async function payTip() {
  const btn = document.getElementById('pay-btn');
  btn.disabled = true;
  btn.textContent = 'Processing...';
  hideTipError();

  try {
    const body = {
      providerId: state.providerId,
      amountPaise: state.amount,
      source: 'PAYMENT_LINK',
      rating: state.rating,
      message: document.getElementById('tip-message').value.trim() || undefined,
      intent: state.intent || undefined,
    };

    const d = await api('POST', '/tips', body);
    state.tipId = d.tipId;

    // Show waiting screen and start polling
    goScreen('waiting');
    startPolling();

    // Fill receipt data for impact screen
    document.getElementById('r-amount').textContent = `₹${(d.amount / 100).toFixed(0)}`;
    document.getElementById('r-tipid').textContent = d.tipId?.substring(0, 12) + '...';
  } catch (e) {
    showTipError(e.message);
  } finally {
    btn.disabled = false;
    updatePayBtn();
  }
}

// ===== Screen 5: Polling =====
function startPolling() {
  state.pollCount = 0;
  // Poll every 3 seconds
  state.pollTimer = setInterval(async () => {
    state.pollCount++;
    try {
      const s = await api('GET', `/tips/${state.tipId}/status`);
      updatePills(s.status);

      if (s.status === 'PAID' || s.status === 'SETTLED') {
        clearInterval(state.pollTimer);
        document.getElementById('r-status').textContent = s.status;
        // Short delay then show impact
        setTimeout(() => showImpact(), 800);
      }
    } catch (e) { /* ignore polling errors */ }

    // Timeout after 40 polls (2 minutes)
    if (state.pollCount >= 40) {
      clearInterval(state.pollTimer);
      document.getElementById('timeout-hint').classList.remove('hidden');
    }
  }, 3000);

  // Also check immediately after 1s (dev mode instant settlement)
  setTimeout(async () => {
    try {
      const s = await api('GET', `/tips/${state.tipId}/status`);
      updatePills(s.status);
      if (s.status === 'PAID' || s.status === 'SETTLED') {
        clearInterval(state.pollTimer);
        document.getElementById('r-status').textContent = s.status;
        setTimeout(() => showImpact(), 500);
      }
    } catch (e) { /* ignore */ }
  }, 1000);
}

function updatePills(status) {
  const initiated = document.getElementById('pill-initiated');
  const paid = document.getElementById('pill-paid');
  const settled = document.getElementById('pill-settled');

  if (status === 'PAID') {
    initiated.className = 'pill done'; initiated.textContent = '✓ Initiated';
    paid.className = 'pill active';
  } else if (status === 'SETTLED') {
    initiated.className = 'pill done'; initiated.textContent = '✓ Initiated';
    paid.className = 'pill done'; paid.textContent = '✓ Paid';
    settled.className = 'pill active';
  }
}

// ===== Screen 6: Impact =====
async function showImpact() {
  goScreen('impact');

  const provName = state.provider?.providerName?.split(' ')[0] || state.publicProfile?.name?.split(' ')[0] || 'their';

  try {
    const impact = await api('GET', `/tips/${state.tipId}/impact`);

    if (impact.dream) {
      document.getElementById('impact-emoji').textContent = '🌟';
      document.getElementById('impact-title').textContent = `You helped ${impact.workerName?.split(' ')[0] || provName}!`;
      document.getElementById('impact-msg').textContent = impact.message;

      const dc = document.getElementById('impact-dream-card');
      dc.classList.remove('hidden');
      document.getElementById('impact-dream-title').textContent = impact.dream.title;
      document.getElementById('impact-goal').textContent = `₹${Math.round(impact.dream.currentAmount / 100)} / ₹${Math.round(impact.dream.goalAmount / 100)}`;
      document.getElementById('impact-pct').textContent = impact.dream.newProgress + '%';

      // Animate: start from previous, fill to new
      const fill = document.getElementById('impact-fill');
      fill.style.width = impact.dream.previousProgress + '%';
      setTimeout(() => { fill.style.width = impact.dream.newProgress + '%'; }, 500);
    } else {
      document.getElementById('impact-emoji').textContent = '🎉';
      document.getElementById('impact-title').textContent = `You made ${provName}'s day!`;
      document.getElementById('impact-msg').textContent = impact.message || `Your tip is on its way to ${provName}.`;
    }
  } catch (e) {
    // Fallback if impact API fails
    document.getElementById('impact-emoji').textContent = '🎉';
    document.getElementById('impact-title').textContent = `You made ${provName}'s day!`;
    document.getElementById('impact-msg').textContent = `Your tip of ₹${(state.amount / 100).toFixed(0)} is on its way!`;
  }

  // Fire confetti
  fireConfetti();
}

// ===== Confetti =====
function fireConfetti() {
  const canvas = document.getElementById('confetti-canvas');
  canvas.classList.remove('hidden');
  const ctx = canvas.getContext('2d');
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;

  const colors = ['#6C5CE7', '#A29BFE', '#00B894', '#FDCB6E', '#E17055', '#FF6B6B', '#55efc4'];
  const pieces = [];
  for (let i = 0; i < 80; i++) {
    pieces.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height - canvas.height,
      w: Math.random() * 8 + 4, h: Math.random() * 6 + 3,
      color: colors[Math.floor(Math.random() * colors.length)],
      vx: (Math.random() - 0.5) * 4, vy: Math.random() * 3 + 2,
      rot: Math.random() * 360, vr: (Math.random() - 0.5) * 10,
    });
  }

  let frame = 0;
  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    pieces.forEach(p => {
      p.x += p.vx; p.y += p.vy; p.rot += p.vr; p.vy += 0.05;
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate(p.rot * Math.PI / 180);
      ctx.fillStyle = p.color;
      ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
      ctx.restore();
    });
    frame++;
    if (frame < 120) requestAnimationFrame(draw);
    else { ctx.clearRect(0, 0, canvas.width, canvas.height); canvas.classList.add('hidden'); }
  }
  draw();
}

// ===== Reset =====
function resetFlow() {
  state.intent = null;
  state.tipId = null;
  state.rating = 5;
  state.pollCount = 0;
  if (state.pollTimer) clearInterval(state.pollTimer);

  // Reset intent tiles
  document.querySelectorAll('.intent-tile').forEach(t => t.classList.remove('active'));
  document.getElementById('intent-next-btn').textContent = 'Continue';

  // Reset amount
  document.getElementById('custom-amount').value = '';
  document.getElementById('tip-message').value = '';
  document.querySelectorAll('.chip').forEach(c => c.classList.remove('active'));
  setRating(5);

  // Reset pills
  document.getElementById('pill-initiated').className = 'pill active';
  document.getElementById('pill-initiated').textContent = 'Initiated';
  document.getElementById('pill-paid').className = 'pill';
  document.getElementById('pill-paid').textContent = 'Paid';
  document.getElementById('pill-settled').className = 'pill';
  document.getElementById('pill-settled').textContent = 'Settled';
  document.getElementById('timeout-hint').classList.add('hidden');

  // Reset impact
  document.getElementById('impact-dream-card').classList.add('hidden');
  document.getElementById('impact-fill').style.width = '0%';

  goScreen('landing');
}

// ===== Subscribe (AutoPay) =====
function initSubscribeScreen() {
  const name = state.provider?.providerName || state.publicProfile?.displayName || 'this provider';
  document.getElementById('sub-name').textContent = name.split(' ')[0];
  updateSubDisplay();
}

function pickFreq(freq) {
  state.subFreq = freq;
  document.querySelectorAll('[data-freq]').forEach(b => {
    b.classList.toggle('active', b.dataset.freq === freq);
  });
  updateSubDisplay();
}

function pickSubAmt(paise) {
  state.subAmount = paise;
  document.querySelectorAll('[data-subamt]').forEach(b => {
    b.classList.toggle('active', parseInt(b.dataset.subamt) === paise);
  });
  updateSubDisplay();
}

function updateSubDisplay() {
  const r = (state.subAmount / 100).toFixed(0);
  const isMonthly = state.subFreq === 'MONTHLY';
  document.getElementById('sub-display-amt').textContent = r;
  document.getElementById('sub-display-freq').textContent = isMonthly ? 'month' : 'week';
  const yearly = isMonthly ? state.subAmount * 12 : state.subAmount * 52;
  document.getElementById('sub-yearly').textContent = (yearly / 100).toLocaleString('en-IN');
  document.getElementById('sub-debit-day').textContent = isMonthly ? '1st of every month' : 'every Monday';
}

async function createSubscription() {
  const btn = document.getElementById('subscribe-btn');
  btn.disabled = true;
  btn.textContent = 'Setting up AutoPay...';

  try {
    // In dev mode, this will create a mock subscription
    const res = await api('POST', '/recurring-tips', {
      providerId: state.providerId,
      amountPaise: state.subAmount,
      frequency: state.subFreq,
    });

    // Show success
    const name = state.provider?.providerName || state.publicProfile?.displayName || 'this worker';
    const isMonthly = state.subFreq === 'MONTHLY';
    document.getElementById('sub-confirm-amt').textContent = (state.subAmount / 100).toFixed(0);
    document.getElementById('sub-confirm-name').textContent = name.split(' ')[0];
    document.getElementById('sub-confirm-freq').textContent = isMonthly ? 'month' : 'week';
    document.getElementById('sub-impact-name').textContent = name.split(' ')[0];

    // Calculate next date
    const next = new Date();
    if (isMonthly) { next.setMonth(next.getMonth() + 1); next.setDate(1); }
    else { next.setDate(next.getDate() + (8 - next.getDay()) % 7); }
    document.getElementById('sub-next-date').textContent = next.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });

    goScreen('sub-success');
  } catch (e) {
    // Mock success for dev mode (API may require auth)
    const name = state.provider?.providerName || state.publicProfile?.displayName || 'this worker';
    const isMonthly = state.subFreq === 'MONTHLY';
    document.getElementById('sub-confirm-amt').textContent = (state.subAmount / 100).toFixed(0);
    document.getElementById('sub-confirm-name').textContent = name.split(' ')[0];
    document.getElementById('sub-confirm-freq').textContent = isMonthly ? 'month' : 'week';
    document.getElementById('sub-impact-name').textContent = name.split(' ')[0];
    const next = new Date();
    if (isMonthly) { next.setMonth(next.getMonth() + 1); next.setDate(1); }
    else { next.setDate(next.getDate() + (8 - next.getDay()) % 7); }
    document.getElementById('sub-next-date').textContent = next.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
    goScreen('sub-success');
  } finally {
    btn.disabled = false;
    btn.textContent = 'Start AutoPay Subscription \uD83D\uDD04';
  }
}

// ===== Helpers =====
function showTipError(msg) { const e = document.getElementById('tip-error'); e.textContent = msg; e.classList.remove('hidden'); }
function hideTipError() { document.getElementById('tip-error').classList.add('hidden'); }
function showFatalError(msg) {
  document.getElementById('loading').classList.add('hidden');
  document.getElementById('error-state').classList.remove('hidden');
  document.getElementById('error-msg').textContent = msg;
}
