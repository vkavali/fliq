// ===== Fliq V5 Tip Flow — Simplified =====
var isCapacitor = Boolean(window.Capacitor && window.Capacitor.isNativePlatform && window.Capacitor.isNativePlatform());
var API = isCapacitor ? 'https://fliq.co.in' : (location.port === '5173' ? 'http://localhost:3000' : location.origin);

var state = {
  shortCode: null,
  providerId: null,
  provider: null,
  publicProfile: null,
  amount: 5000, // default ₹50
  tipId: null,
  pollTimer: null,
  pollCount: 0,
  subAmount: 10000,
};

// ===== Init =====
(async function init() {
  var parts = location.pathname.split('/').filter(Boolean);
  var code = parts[parts.length - 1];
  if (!code) { showFatalError('Invalid tip link'); return; }
  state.shortCode = code;

  try {
    var resolved = false;

    // Try 1: Resolve as payment link short code
    try {
      var data = await api('GET', '/payment-links/' + code + '/resolve');
      state.providerId = data.providerId;
      state.provider = data;
      resolved = true;

      // Fetch enhanced public profile
      try {
        var pub = await api('GET', '/providers/' + data.providerId + '/public');
        state.publicProfile = pub;
      } catch (e) { /* non-fatal */ }

      renderTipScreen(state.provider, state.publicProfile);
    } catch (e) {
      // Not a payment link
    }

    // Try 2: Resolve as provider ID
    if (!resolved) {
      try {
        var pub = await api('GET', '/providers/' + code + '/public');
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
        renderTipScreen(state.provider, pub);
        resolved = true;
      } catch (e2) {
        // Not a provider either
      }
    }

    if (!resolved) {
      showFatalError('This tip link could not be found. It may have expired or been deactivated.');
      return;
    }

    document.getElementById('loading').classList.add('hidden');
    document.getElementById('screen-tip').classList.remove('hidden');
  } catch (e) {
    showFatalError(e.message || 'This tip link may have expired.');
  }
})();

// ===== API =====
function api(method, path, body) {
  var controller = new AbortController();
  var timeout = setTimeout(function() { controller.abort(); }, 10000);
  var opts = { method: method, headers: { 'Content-Type': 'application/json' }, signal: controller.signal };
  if (body) opts.body = JSON.stringify(body);
  return fetch(API + path, opts)
    .then(function(r) {
      return r.json().catch(function() { return {}; }).then(function(d) {
        if (!r.ok) throw new Error(d.message || 'Error ' + r.status);
        return d;
      });
    })
    .catch(function(e) {
      if (e.name === 'AbortError') throw new Error('Request timed out — server may be restarting');
      throw e;
    })
    .finally(function() { clearTimeout(timeout); });
}

// ===== Render Screen 1: Tip =====
function renderTipScreen(data, pub) {
  var name = data.providerName || (pub && pub.name) || 'Service Provider';
  var firstName = name.split(' ')[0];

  // Avatar
  var avatarEl = document.getElementById('avatar');
  var avatarUrl = data.avatarUrl || (pub && pub.avatarUrl);
  if (avatarUrl) {
    avatarEl.innerHTML = '<img src="' + avatarUrl + '" alt="' + name + '">';
  } else {
    avatarEl.textContent = name[0].toUpperCase();
  }

  // Name
  document.getElementById('worker-name').textContent = name;

  // Category pill
  var cat = data.category || (pub && pub.category);
  var pillEl = document.getElementById('category-pill');
  if (cat && cat !== '-' && cat !== 'OTHER') {
    pillEl.textContent = cat.charAt(0) + cat.slice(1).toLowerCase();
    pillEl.classList.remove('hidden');
  }

  // Trust line
  document.getElementById('trust-line').textContent = '✓ 100% goes to ' + firstName;

  // Stats
  var totalTips = (pub && pub.totalTipsReceived) || data.totalTipsReceived || 0;
  document.getElementById('stat-total').textContent = totalTips;
  if (pub && pub.stats) {
    document.getElementById('stat-today').textContent = pub.stats.tipsToday || 0;
    document.getElementById('stat-recent').textContent = pub.stats.recentAppreciations || 0;
  }

  // Trust score in details panel
  if (pub && pub.reputation && pub.reputation.score > 0) {
    document.getElementById('detail-trust-score').textContent = Math.round(pub.reputation.score) + '/100';
    document.getElementById('detail-trust').classList.remove('hidden');
  }

  // Dream in details panel
  if (pub && pub.dream) {
    var d = pub.dream;
    document.getElementById('detail-dream-title').textContent = d.title;
    document.getElementById('detail-dream-desc').textContent = d.description || '';
    var pct = d.percentage || 0;
    setTimeout(function() { document.getElementById('detail-dream-fill').style.width = pct + '%'; }, 300);
    document.getElementById('detail-dream-pct').textContent = pct + '%';
    document.getElementById('detail-dream-amounts').textContent = '₹' + Math.round(d.currentAmount / 100) + ' / ₹' + Math.round(d.goalAmount / 100);
    document.getElementById('detail-dream').classList.remove('hidden');
  }

  // Suggested amount
  if (data.suggestedAmountPaise && data.suggestedAmountPaise >= 1000) {
    state.amount = data.suggestedAmountPaise;
    updateAmountDisplay();
  }
}

// ===== Amount selection =====
function pickAmt(paise) {
  state.amount = paise;
  document.getElementById('custom-amount').value = '';
  // Update chips
  var chips = document.querySelectorAll('.chip-btn');
  for (var i = 0; i < chips.length; i++) {
    chips[i].classList.toggle('active', parseInt(chips[i].getAttribute('data-paise')) === paise);
  }
  updateAmountDisplay();
}

function onCustomAmount() {
  var v = parseInt(document.getElementById('custom-amount').value) || 0;
  if (v > 0) {
    state.amount = v * 100;
    // Deselect all chips
    var chips = document.querySelectorAll('.chip-btn');
    for (var i = 0; i < chips.length; i++) chips[i].classList.remove('active');
    updateAmountDisplay();
  }
}

function updateAmountDisplay() {
  var rupees = Math.round(state.amount / 100);
  document.getElementById('big-amount').textContent = '₹ ' + rupees;
  document.getElementById('pay-btn').textContent = 'Pay ₹' + rupees;
}

// ===== More details toggle =====
function toggleDetails() {
  var panel = document.getElementById('details-panel');
  var btn = document.getElementById('details-toggle');
  if (panel.classList.contains('hidden')) {
    panel.classList.remove('hidden');
    btn.textContent = 'Less details ↑';
  } else {
    panel.classList.add('hidden');
    btn.textContent = 'More details ↓';
  }
}

// ===== Pay =====
function payTip() {
  var btn = document.getElementById('pay-btn');
  btn.disabled = true;
  btn.textContent = 'Processing...';
  hideTipError();

  var body = {
    providerId: state.providerId,
    amountPaise: state.amount,
    source: 'PAYMENT_LINK',
  };

  api('POST', '/tips', body)
    .then(function(d) {
      state.tipId = d.tipId;

      // Pre-fill receipt data
      document.getElementById('r-amount').textContent = '₹' + Math.round(d.amount / 100);
      document.getElementById('r-tipid').textContent = d.tipId ? d.tipId.substring(0, 12) + '...' : '-';

      // Show waiting screen
      showScreen('waiting');
      startPolling();
    })
    .catch(function(e) {
      showTipError(e.message);
    })
    .finally(function() {
      btn.disabled = false;
      updateAmountDisplay();
    });
}

// ===== Screen navigation =====
function showScreen(name) {
  var screens = ['loading', 'screen-tip', 'screen-waiting', 'screen-done', 'screen-error'];
  for (var i = 0; i < screens.length; i++) {
    var el = document.getElementById(screens[i]);
    if (el) el.classList.add('hidden');
  }
  var map = { tip: 'screen-tip', waiting: 'screen-waiting', done: 'screen-done', error: 'screen-error' };
  var target = document.getElementById(map[name]);
  if (target) target.classList.remove('hidden');
}

// ===== Polling =====
function startPolling() {
  state.pollCount = 0;

  state.pollTimer = setInterval(function() {
    state.pollCount++;
    pollStatus();

    // Timeout after 40 polls (~2 minutes)
    if (state.pollCount >= 40) {
      clearInterval(state.pollTimer);
      document.getElementById('timeout-hint').classList.remove('hidden');
    }
  }, 3000);

  // Quick check after 1s for dev mode instant settlement
  setTimeout(function() { pollStatus(); }, 1000);
}

function pollStatus() {
  api('GET', '/tips/' + state.tipId + '/status')
    .then(function(s) {
      updatePills(s.status);
      if (s.status === 'PAID' || s.status === 'SETTLED') {
        clearInterval(state.pollTimer);
        document.getElementById('r-status').textContent = s.status;
        setTimeout(function() { showDone(); }, 800);
      }
    })
    .catch(function() { /* ignore polling errors */ });
}

function updatePills(status) {
  var initiated = document.getElementById('pill-initiated');
  var paid = document.getElementById('pill-paid');
  var settled = document.getElementById('pill-settled');

  if (status === 'PAID') {
    initiated.className = 'pill done'; initiated.textContent = '✓ Initiated';
    paid.className = 'pill active';
  } else if (status === 'SETTLED') {
    initiated.className = 'pill done'; initiated.textContent = '✓ Initiated';
    paid.className = 'pill done'; paid.textContent = '✓ Paid';
    settled.className = 'pill active';
  }
}

// ===== Screen 3: Done =====
function showDone() {
  showScreen('done');

  var provName = (state.provider && state.provider.providerName) ? state.provider.providerName.split(' ')[0] : ((state.publicProfile && state.publicProfile.name) ? state.publicProfile.name.split(' ')[0] : 'them');
  var rupees = Math.round(state.amount / 100);

  document.getElementById('done-title').textContent = '₹' + rupees + ' sent to ' + provName;
  document.getElementById('done-subtitle').textContent = '';

  // Set subscribe name
  document.getElementById('sub-name').textContent = provName;

  // Fetch impact
  api('GET', '/tips/' + state.tipId + '/impact')
    .then(function(impact) {
      if (impact.dream) {
        var dc = document.getElementById('done-dream');
        dc.classList.remove('hidden');
        document.getElementById('done-dream-title').textContent = impact.dream.title;
        document.getElementById('done-dream-goal').textContent = '₹' + Math.round(impact.dream.currentAmount / 100) + ' / ₹' + Math.round(impact.dream.goalAmount / 100);
        document.getElementById('done-dream-pct').textContent = impact.dream.newProgress + '%';

        var fill = document.getElementById('done-dream-fill');
        fill.style.transition = 'width 1.2s ease-out';
        fill.style.width = impact.dream.previousProgress + '%';
        setTimeout(function() { fill.style.width = impact.dream.newProgress + '%'; }, 400);
      }
      if (impact.message) {
        document.getElementById('done-subtitle').textContent = impact.message;
      }
    })
    .catch(function() {
      document.getElementById('done-subtitle').textContent = 'Your tip is on its way!';
    });
}

// ===== Reset =====
function resetFlow() {
  state.tipId = null;
  state.pollCount = 0;
  if (state.pollTimer) clearInterval(state.pollTimer);

  // Reset custom amount input
  document.getElementById('custom-amount').value = '';

  // Reset to ₹50 default
  state.amount = 5000;
  pickAmt(5000);

  // Reset pills
  document.getElementById('pill-initiated').className = 'pill active';
  document.getElementById('pill-initiated').textContent = 'Initiated';
  document.getElementById('pill-paid').className = 'pill';
  document.getElementById('pill-paid').textContent = 'Paid';
  document.getElementById('pill-settled').className = 'pill';
  document.getElementById('pill-settled').textContent = 'Settled';
  document.getElementById('timeout-hint').classList.add('hidden');

  // Reset done screen
  document.getElementById('done-dream').classList.add('hidden');
  document.getElementById('done-dream-fill').style.width = '0%';
  document.getElementById('subscribe-section').classList.add('hidden');
  document.getElementById('subscribe-link').classList.remove('hidden');

  showScreen('tip');
}

// ===== Subscribe (inline on done screen) =====
function showSubscribe() {
  document.getElementById('subscribe-section').classList.remove('hidden');
  document.getElementById('subscribe-link').classList.add('hidden');
}

function pickSubAmt(paise) {
  state.subAmount = paise;
  var chips = document.querySelectorAll('.sub-chip');
  for (var i = 0; i < chips.length; i++) {
    chips[i].classList.toggle('active', parseInt(chips[i].getAttribute('data-subamt')) === paise);
  }
  document.getElementById('autopay-btn').textContent = 'Start AutoPay ₹' + Math.round(paise / 100) + '/month';
}

function createSubscription() {
  var btn = document.getElementById('autopay-btn');
  var errEl = document.getElementById('sub-error');
  btn.disabled = true;
  btn.textContent = 'Setting up...';
  errEl.classList.add('hidden');

  api('POST', '/recurring-tips', {
    providerId: state.providerId,
    amountPaise: state.subAmount,
    frequency: 'MONTHLY',
  })
    .then(function() {
      btn.textContent = '✓ Subscribed!';
      btn.style.background = '#00B894';
    })
    .catch(function(e) {
      var msg = e.message || 'Failed to set up subscription';
      if (msg.indexOf('401') !== -1 || msg.toLowerCase().indexOf('unauthorized') !== -1) {
        msg = 'Please log in to set up a recurring subscription.';
      }
      errEl.textContent = msg;
      errEl.classList.remove('hidden');
      btn.disabled = false;
      btn.textContent = 'Start AutoPay ₹' + Math.round(state.subAmount / 100) + '/month';
    });
}

// ===== Helpers =====
function showTipError(msg) {
  var e = document.getElementById('tip-error');
  e.textContent = msg;
  e.classList.remove('hidden');
}

function hideTipError() {
  document.getElementById('tip-error').classList.add('hidden');
}

function showFatalError(msg) {
  document.getElementById('loading').classList.add('hidden');
  document.getElementById('screen-error').classList.remove('hidden');
  document.getElementById('error-msg').textContent = msg;
}

// ===== Service Worker =====
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/app/sw.js').catch(function() {});
}
