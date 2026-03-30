/* ===== Claude Code Dashboard SPA ===== */

(function () {
  'use strict';

  var data = null;
  var currentFilter = 'all';
  var currentVerifyTab = 'pending';

  // ===== Theme Toggle =====
  var toggleBtn = document.getElementById('themeToggle');
  var htmlEl = document.documentElement;
  var savedTheme = localStorage.getItem('theme') || 'dark';
  if (savedTheme === 'light') {
    htmlEl.setAttribute('data-theme', 'light');
    toggleBtn.textContent = '\u2600\uFE0F';
  }
  toggleBtn.addEventListener('click', function () {
    if (htmlEl.getAttribute('data-theme') === 'light') {
      htmlEl.removeAttribute('data-theme');
      toggleBtn.textContent = '\uD83C\uDF19';
      localStorage.setItem('theme', 'dark');
    } else {
      htmlEl.setAttribute('data-theme', 'light');
      toggleBtn.textContent = '\u2600\uFE0F';
      localStorage.setItem('theme', 'light');
    }
  });

  // ===== Data Loading =====
  function loadData(callback) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', 'data.json');
    xhr.onload = function () {
      if (xhr.status === 200) {
        data = JSON.parse(xhr.responseText);
        callback();
      }
    };
    xhr.send();
  }

  // ===== Utility: Create Element Helper =====
  function el(tag, attrs, children) {
    var elem = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (key) {
        if (key === 'className') {
          elem.className = attrs[key];
        } else if (key === 'textContent') {
          elem.textContent = attrs[key];
        } else if (key.indexOf('on') === 0) {
          elem.addEventListener(key.substring(2).toLowerCase(), attrs[key]);
        } else {
          elem.setAttribute(key, attrs[key]);
        }
      });
    }
    if (children) {
      if (!Array.isArray(children)) children = [children];
      children.forEach(function (child) {
        if (typeof child === 'string') {
          elem.appendChild(document.createTextNode(child));
        } else if (child) {
          elem.appendChild(child);
        }
      });
    }
    return elem;
  }

  // ===== Safe Markdown Rendering =====
  // Only used for content from our own repository (SKILL.md files and config .md files).
  // This is the approved exception to the innerHTML rule per design requirements.
  function renderMarkdown(markdownText) {
    var div = document.createElement('div');
    div.className = 'sd-content';
    if (typeof marked !== 'undefined' && markdownText) {
      div.innerHTML = marked.parse(markdownText);
    }
    return div;
  }

  // ===== Sidebar Badges =====
  function updateSidebar() {
    if (!data) return;
    var stats = data.stats;
    document.getElementById('badge-skills').textContent = stats.total_skills;
    document.getElementById('badge-hooks').textContent = stats.total_hooks;
    document.getElementById('badge-configs').textContent = stats.total_configs;
    document.getElementById('badge-scripts').textContent = stats.total_scripts;
    document.getElementById('badge-verify').textContent = stats.total_pending;

    // Footer
    if (data.git) {
      document.getElementById('footer-branch').textContent = data.git.branch;
    }
    if (data.generated_at) {
      var dateStr = data.generated_at.substring(0, 10);
      document.getElementById('footer-updated').textContent = 'Last updated: ' + dateStr;
    }

    // Skills sub-nav
    var subNav = document.getElementById('skills-sub');
    while (subNav.firstChild) subNav.removeChild(subNav.firstChild);
    var sources = {};
    data.skills.forEach(function (s) {
      var src = s.source || 'unknown';
      sources[src] = (sources[src] || 0) + 1;
    });
    var allItem = el('div', { className: 'nav-sub-item', 'data-filter': 'all' },
      'All (' + data.skills.length + ')');
    subNav.appendChild(allItem);
    Object.keys(sources).sort().forEach(function (src) {
      var item = el('div', { className: 'nav-sub-item', 'data-filter': src },
        src + ' (' + sources[src] + ')');
      subNav.appendChild(item);
    });
  }

  // ===== Breadcrumb =====
  var pageNames = {
    dashboard: 'Overview',
    skills: 'Skills',
    hooks: 'Hooks',
    configs: 'Configs',
    memory: 'Memory',
    verify: 'Verification',
    scripts: 'Scripts'
  };

  function updateBreadcrumb(page, extra) {
    var bc = document.getElementById('breadcrumb');
    while (bc.firstChild) bc.removeChild(bc.firstChild);

    var home = el('span', { className: 'bc-link', 'data-page': 'dashboard', textContent: 'Dashboard' });
    bc.appendChild(home);

    if (page === 'dashboard') {
      bc.appendChild(document.createTextNode(' / '));
      bc.appendChild(el('span', { className: 'current', textContent: 'Overview' }));
    } else if (page === 'skill-detail') {
      bc.appendChild(document.createTextNode(' / '));
      var skillsLink = el('span', { className: 'bc-link', 'data-page': 'skills', textContent: 'Skills' });
      bc.appendChild(skillsLink);
      bc.appendChild(document.createTextNode(' / '));
      bc.appendChild(el('span', { className: 'current', textContent: extra || 'Detail' }));
    } else {
      bc.appendChild(document.createTextNode(' / '));
      bc.appendChild(el('span', { className: 'current', textContent: pageNames[page] || page }));
    }
  }

  // ===== Active Nav =====
  function setActiveNav(page) {
    var navPage = (page === 'skill-detail') ? 'skills' : page;
    var items = document.querySelectorAll('.nav-item');
    for (var i = 0; i < items.length; i++) {
      items[i].classList.remove('active');
      if (items[i].getAttribute('data-page') === navPage) {
        items[i].classList.add('active');
      }
    }
  }

  // ===== Page Renderers =====

  // --- Dashboard ---
  function renderDashboard() {
    var content = document.getElementById('content');
    while (content.firstChild) content.removeChild(content.firstChild);
    var stats = data.stats;

    content.appendChild(el('div', { className: 'page-title', textContent: 'Dashboard' }));
    content.appendChild(el('div', { className: 'page-desc' },
      'Claude Code configuration overview \u2014 auto-generated on every push'));

    // Stat cards
    var grid = el('div', { className: 'stat-grid' });
    var cards = [
      { label: 'Skills', value: stats.total_skills, sub: Object.keys(getSourceCounts()).length + ' collections', color: 'color-accent', page: 'skills' },
      { label: 'Verified', value: stats.total_verified, sub: stats.total_pending + ' pending', color: 'color-green', page: 'verify' },
      { label: 'Scripts', value: stats.total_scripts_lines.toLocaleString(), sub: 'lines of bash', color: 'color-yellow', page: 'scripts' },
      { label: 'Plugins', value: stats.total_plugins, sub: 'recommended', color: 'color-purple', page: null }
    ];

    cards.forEach(function (c) {
      var card = el('div', { className: 'stat-card' });
      if (c.page) {
        card.setAttribute('data-navigate', c.page);
      }
      card.appendChild(el('div', { className: 'stat-label', textContent: c.label }));
      card.appendChild(el('div', { className: 'stat-value ' + c.color, textContent: String(c.value) }));
      card.appendChild(el('div', { className: 'stat-sub', textContent: c.sub }));
      grid.appendChild(card);
    });
    content.appendChild(grid);

    // Recent Activity
    content.appendChild(el('div', { className: 'section-title', textContent: 'Recent Activity' }));
    var actList = el('div', { className: 'activity-list' });

    // Combine pending and verified, sort by date desc, take 5
    var activities = [];
    (data.verify.pending || []).forEach(function (v) {
      activities.push({ title: v.title, date: v.date, type: 'pending' });
    });
    (data.verify.verified || []).forEach(function (v) {
      activities.push({ title: v.title, date: v.date, type: 'verified' });
    });
    activities.sort(function (a, b) { return b.date.localeCompare(a.date); });
    activities = activities.slice(0, 5);

    activities.forEach(function (act) {
      var item = el('div', { className: 'activity-item' });
      var icon = el('span', {
        className: act.type === 'pending' ? 'activity-icon-pending' : 'activity-icon-verified'
      });
      icon.textContent = act.type === 'pending' ? '\u25CB' : '\u2713';
      item.appendChild(icon);
      item.appendChild(el('span', { className: 'activity-text', textContent: act.title }));
      item.appendChild(el('span', { className: 'activity-date', textContent: act.date }));
      actList.appendChild(item);
    });
    content.appendChild(actList);
  }

  function getSourceCounts() {
    var counts = {};
    data.skills.forEach(function (s) {
      var src = s.source || 'unknown';
      counts[src] = (counts[src] || 0) + 1;
    });
    return counts;
  }

  // --- Skills ---
  function renderSkills() {
    var content = document.getElementById('content');
    while (content.firstChild) content.removeChild(content.firstChild);

    var counts = getSourceCounts();
    var total = data.skills.length;

    content.appendChild(el('div', { className: 'page-title', textContent: 'Skills' }));
    content.appendChild(el('div', { className: 'page-desc' },
      total + ' skills across ' + Object.keys(counts).length + ' collections \u2014 auto-triggered capabilities'));

    // Filter bar
    var filterBar = el('div', { className: 'skill-filter-bar' });
    var allChip = el('span', {
      className: 'filter-chip' + (currentFilter === 'all' ? ' active' : ''),
      'data-filter': 'all'
    });
    allChip.appendChild(document.createTextNode('All'));
    allChip.appendChild(el('span', { className: 'chip-count', textContent: ' ' + total }));
    filterBar.appendChild(allChip);

    Object.keys(counts).sort().forEach(function (src) {
      var chip = el('span', {
        className: 'filter-chip' + (currentFilter === src ? ' active' : ''),
        'data-filter': src
      });
      chip.appendChild(document.createTextNode(src));
      chip.appendChild(el('span', { className: 'chip-count', textContent: ' ' + counts[src] }));
      filterBar.appendChild(chip);
    });
    content.appendChild(filterBar);

    // Skills list
    var listContainer = el('div', { id: 'skillsList' });
    data.skills.forEach(function (skill) {
      var show = currentFilter === 'all' || skill.source === currentFilter;
      var row = el('div', {
        className: 'skill-row',
        'data-source': skill.source,
        'data-skill-name': skill.name,
        style: show ? '' : 'display:none'
      });
      row.appendChild(el('span', { className: 'sr-name', textContent: skill.name }));
      row.appendChild(el('span', { className: 'sr-source', textContent: skill.source }));
      // Truncate description for display
      var desc = skill.description || '';
      if (desc.length > 100) desc = desc.substring(0, 100) + '...';
      row.appendChild(el('span', { className: 'sr-desc', textContent: desc }));
      row.appendChild(el('span', { className: 'sr-version', textContent: skill.version ? 'v' + skill.version : '' }));
      listContainer.appendChild(row);
    });
    content.appendChild(listContainer);
  }

  // --- Skill Detail ---
  function renderSkillDetail(skillName) {
    var content = document.getElementById('content');
    while (content.firstChild) content.removeChild(content.firstChild);

    var skill = null;
    for (var i = 0; i < data.skills.length; i++) {
      if (data.skills[i].name === skillName) {
        skill = data.skills[i];
        break;
      }
    }
    if (!skill) {
      content.appendChild(el('div', { className: 'page-title', textContent: 'Skill Not Found' }));
      return;
    }

    // Back link
    var back = el('div', { className: 'sd-back', textContent: '\u2190 Back to Skills', id: 'backToSkills' });
    content.appendChild(back);

    // Detail card
    var detail = el('div', { className: 'skill-detail' });

    // Header
    var header = el('div', { className: 'skill-detail-header' });
    header.appendChild(el('div', { className: 'sd-title', textContent: skill.name }));
    var meta = el('div', { className: 'sd-meta' });
    meta.appendChild(el('span', { textContent: '\uD83D\uDCE6 ' + skill.source }));
    if (skill.version) {
      meta.appendChild(el('span', { textContent: '\uD83C\uDFF7 v' + skill.version }));
    }
    meta.appendChild(el('span', { textContent: '\uD83D\uDCC4 ' + (skill.file || '') }));
    header.appendChild(meta);
    detail.appendChild(header);

    // Body
    var body = el('div', { className: 'skill-detail-body' });

    // Frontmatter
    var fm = el('div', { className: 'sd-frontmatter' });
    fm.appendChild(el('span', { className: 'fm-comment', textContent: '---' }));
    fm.appendChild(document.createElement('br'));

    var fmFields = [
      { key: 'name', val: skill.name },
      { key: 'description', val: skill.description ? skill.description.substring(0, 80) : '' },
      { key: 'version', val: skill.version || '' }
    ];
    fmFields.forEach(function (f) {
      fm.appendChild(el('span', { className: 'fm-key', textContent: f.key }));
      fm.appendChild(document.createTextNode(': '));
      fm.appendChild(el('span', { className: 'fm-val', textContent: f.val }));
      fm.appendChild(document.createElement('br'));
    });
    fm.appendChild(el('span', { className: 'fm-comment', textContent: '---' }));
    body.appendChild(fm);

    // Markdown content - rendered from our own SKILL.md files (safe, per design spec)
    if (skill.content) {
      body.appendChild(renderMarkdown(skill.content));
    }

    detail.appendChild(body);
    content.appendChild(detail);
  }

  // --- Hooks ---
  function renderHooks() {
    var content = document.getElementById('content');
    while (content.firstChild) content.removeChild(content.firstChild);

    content.appendChild(el('div', { className: 'page-title', textContent: 'Hooks' }));
    content.appendChild(el('div', { className: 'page-desc' },
      data.hooks.length + ' hook configurations \u2014 event-driven automation'));

    data.hooks.forEach(function (hook) {
      var card = el('div', { className: 'hook-card' });

      var header = el('div', { className: 'hook-card-header' });
      header.appendChild(el('span', { className: 'hc-name', textContent: hook.name }));

      // Event badges
      (hook.events || []).forEach(function (evt) {
        var evtLower = evt.toLowerCase();
        var badgeClass = 'event-badge ';
        if (evtLower === 'notification') badgeClass += 'event-notification';
        else if (evtLower === 'stop') badgeClass += 'event-stop';
        else if (evtLower === 'pretooluse') badgeClass += 'event-pretooluse';
        else if (evtLower === 'posttooluse') badgeClass += 'event-posttooluse';
        else badgeClass += 'event-default';
        header.appendChild(el('span', { className: badgeClass, textContent: evt }));
      });

      header.appendChild(el('span', { className: 'hc-file', textContent: hook.file }));

      if (hook.description) {
        header.appendChild(el('div', { className: 'hc-desc', textContent: hook.description }));
      }
      card.appendChild(header);

      // Expandable JSON content
      var contentDiv = el('div', { className: 'hook-content' });
      var pre = document.createElement('pre');
      try {
        var parsed = JSON.parse(hook.content);
        pre.textContent = JSON.stringify(parsed, null, 2);
      } catch (e) {
        pre.textContent = hook.content;
      }
      contentDiv.appendChild(pre);
      card.appendChild(contentDiv);

      content.appendChild(card);
    });
  }

  // --- Configs ---
  function renderConfigs() {
    var content = document.getElementById('content');
    while (content.firstChild) content.removeChild(content.firstChild);

    content.appendChild(el('div', { className: 'page-title', textContent: 'Configs' }));
    content.appendChild(el('div', { className: 'page-desc' },
      data.configs.length + ' configuration files'));

    data.configs.forEach(function (config) {
      var card = el('div', { className: 'config-card' });

      var header = el('div', { className: 'config-card-header' });
      header.appendChild(el('div', { className: 'cc-name', textContent: config.name }));
      header.appendChild(el('div', { className: 'cc-path', textContent: config.file }));
      card.appendChild(header);

      // Expandable content
      var contentDiv = el('div', { className: 'config-content' });
      var isMd = config.file && config.file.endsWith('.md');
      var isJson = config.file && config.file.endsWith('.json');

      if (isMd && config.content) {
        // Render markdown - safe because content comes from our own repo config files
        contentDiv.appendChild(renderMarkdown(config.content));
      } else if (isJson && config.content) {
        var pre = document.createElement('pre');
        try {
          var parsed = JSON.parse(config.content);
          pre.textContent = JSON.stringify(parsed, null, 2);
        } catch (e) {
          pre.textContent = config.content;
        }
        contentDiv.appendChild(pre);
      } else if (config.content) {
        var pre = document.createElement('pre');
        pre.textContent = config.content;
        contentDiv.appendChild(pre);
      }
      card.appendChild(contentDiv);
      content.appendChild(card);
    });
  }

  // --- Memory ---
  function renderMemory() {
    var content = document.getElementById('content');
    while (content.firstChild) content.removeChild(content.firstChild);

    content.appendChild(el('div', { className: 'page-title', textContent: 'Memory' }));
    content.appendChild(el('div', { className: 'page-desc' },
      'Persistent cross-session memory \u2014 private data requires authentication'));

    var gate = el('div', { className: 'auth-gate' });
    gate.appendChild(el('div', { className: 'lock-icon', textContent: '\uD83D\uDD12' }));
    gate.appendChild(el('h2', { textContent: 'Private Memory Data' }));

    var desc = el('p');
    desc.appendChild(document.createTextNode('Memory data is stored privately.'));
    desc.appendChild(document.createElement('br'));
    desc.appendChild(document.createTextNode('Enter your access token to view full content.'));
    gate.appendChild(desc);

    var inputRow = el('div', { className: 'auth-input' });
    var input = el('input', { type: 'password', placeholder: 'Enter access token...' });
    inputRow.appendChild(input);
    var btn = el('button', { className: 'auth-btn', textContent: 'Unlock' });
    inputRow.appendChild(btn);
    gate.appendChild(inputRow);

    var msg = el('div', { className: 'auth-message', textContent: 'MEMORY_GIST_ID not configured yet' });
    gate.appendChild(msg);

    gate.appendChild(el('p', { className: 'auth-note', textContent: 'Token is only used client-side, never transmitted' }));

    btn.addEventListener('click', function () {
      msg.classList.add('visible');
    });

    content.appendChild(gate);
  }

  // --- Verification ---
  function renderVerify() {
    var content = document.getElementById('content');
    while (content.firstChild) content.removeChild(content.firstChild);

    var verify = data.verify;
    var totalItems = (verify.verified || []).length + (verify.pending || []).length;
    var verifiedCount = (verify.verified || []).length;
    var pct = totalItems > 0 ? Math.round((verifiedCount / totalItems) * 100) : 0;

    content.appendChild(el('div', { className: 'page-title', textContent: 'Verification' }));
    content.appendChild(el('div', { className: 'page-desc' },
      'Track verification status of configuration changes'));

    // Progress bar
    var progress = el('div', { className: 'verify-progress' });
    progress.appendChild(el('div', { className: 'vp-label',
      textContent: verifiedCount + ' / ' + totalItems + ' verified (' + pct + '%)' }));
    var bar = el('div', { className: 'vp-bar' });
    var fill = el('div', { className: 'vp-fill' });
    fill.style.width = pct + '%';
    bar.appendChild(fill);
    progress.appendChild(bar);
    progress.appendChild(el('div', { className: 'vp-stats',
      textContent: (verify.pending || []).length + ' pending \u00B7 ' +
        verifiedCount + ' verified \u00B7 ' +
        (verify.deprecated || []).length + ' deprecated' }));
    content.appendChild(progress);

    // Tabs
    var tabs = el('div', { className: 'verify-tabs' });
    ['pending', 'verified', 'deprecated'].forEach(function (tab) {
      var count = (verify[tab] || []).length;
      var tabBtn = el('button', {
        className: 'verify-tab' + (currentVerifyTab === tab ? ' active' : ''),
        'data-verify-tab': tab,
        textContent: tab.charAt(0).toUpperCase() + tab.slice(1) + ' (' + count + ')'
      });
      tabs.appendChild(tabBtn);
    });
    content.appendChild(tabs);

    // Items list
    var list = el('div', { className: 'verify-list', id: 'verifyList' });
    renderVerifyItems(list);
    content.appendChild(list);
  }

  function renderVerifyItems(list) {
    if (!list) list = document.getElementById('verifyList');
    if (!list) return;
    while (list.firstChild) list.removeChild(list.firstChild);

    var items = data.verify[currentVerifyTab] || [];
    if (items.length === 0) {
      list.appendChild(el('div', { className: 'page-desc', textContent: 'No items in this category.' }));
      return;
    }

    items.forEach(function (v) {
      var item = el('div', { className: 'verify-item' });
      var header = el('div', { className: 'vi-header' });

      // Marker icon
      var markerText, markerClass, titleClass;
      if (currentVerifyTab === 'pending') {
        markerText = '\u25CB';
        markerClass = 'vi-marker vi-marker-pending';
        titleClass = 'vi-title';
      } else if (currentVerifyTab === 'verified') {
        markerText = '\u2713';
        markerClass = 'vi-marker vi-marker-verified';
        titleClass = 'vi-title';
      } else {
        markerText = '\u2717';
        markerClass = 'vi-marker vi-marker-deprecated';
        titleClass = 'vi-title deprecated';
      }
      header.appendChild(el('span', { className: markerClass, textContent: markerText }));
      header.appendChild(el('span', { className: titleClass, textContent: v.title }));

      if (v.commit && v.commit !== 'pending') {
        header.appendChild(el('span', { className: 'vi-commit', textContent: v.commit }));
      }
      if (v.date) {
        header.appendChild(el('span', { className: 'vi-date', textContent: v.date }));
      }
      item.appendChild(header);

      // Detail fields
      var detailDiv = el('div', { className: 'vi-detail' });
      if (currentVerifyTab === 'pending') {
        if (v.method) {
          var line1 = document.createElement('div');
          line1.appendChild(el('span', { className: 'vi-detail-label', textContent: 'Method' }));
          line1.appendChild(document.createTextNode(v.method));
          detailDiv.appendChild(line1);
        }
        if (v.expected) {
          var line2 = document.createElement('div');
          line2.appendChild(el('span', { className: 'vi-detail-label', textContent: 'Expected' }));
          line2.appendChild(document.createTextNode(v.expected));
          detailDiv.appendChild(line2);
        }
      } else if (currentVerifyTab === 'verified') {
        if (v.actual || v.method) {
          var line3 = document.createElement('div');
          line3.appendChild(el('span', { className: 'vi-detail-label', textContent: 'Result' }));
          line3.appendChild(document.createTextNode(v.actual || v.method || ''));
          detailDiv.appendChild(line3);
        }
      } else {
        if (v.reason) {
          var line4 = document.createElement('div');
          line4.appendChild(el('span', { className: 'vi-detail-label', textContent: 'Reason' }));
          line4.appendChild(document.createTextNode(v.reason));
          detailDiv.appendChild(line4);
        }
      }
      item.appendChild(detailDiv);
      list.appendChild(item);
    });
  }

  // --- Scripts ---
  function renderScripts() {
    var content = document.getElementById('content');
    while (content.firstChild) content.removeChild(content.firstChild);

    var totalLines = data.stats.total_scripts_lines;
    content.appendChild(el('div', { className: 'page-title', textContent: 'Scripts' }));
    content.appendChild(el('div', { className: 'page-desc' },
      data.scripts.length + ' executable shell scripts \u2014 ' + totalLines.toLocaleString() + ' lines of bash'));

    // Known dependencies per script (hardcoded since deps field is unreliable in data.json)
    var knownDeps = {
      'telegram-bridge.sh': ['jq', 'tmux', 'curl'],
      'notify-telegram.sh': ['jq', 'curl'],
      'statusline.sh': ['jq']
    };

    data.scripts.forEach(function (script) {
      var card = el('div', { className: 'script-card' });
      var header = el('div', { className: 'sc-header' });
      header.appendChild(el('span', { className: 'sc-name', textContent: script.name }));
      header.appendChild(el('span', { className: 'sc-lines', textContent: script.lines + ' lines' }));
      card.appendChild(header);

      if (script.description) {
        card.appendChild(el('div', { className: 'sc-desc', textContent: script.description }));
      }

      var deps = knownDeps[script.name] || [];
      if (deps.length > 0) {
        var depsDiv = el('div', { className: 'sc-deps' });
        deps.forEach(function (dep) {
          depsDiv.appendChild(el('span', { className: 'dep-tag', textContent: dep }));
        });
        card.appendChild(depsDiv);
      }

      content.appendChild(card);
    });
  }

  // ===== Router =====
  function getRoute() {
    var hash = window.location.hash.replace('#', '') || 'dashboard';
    var parts = hash.split('/');
    return { page: parts[0], param: parts.slice(1).join('/') };
  }

  function navigate(page, param) {
    if (param) {
      window.location.hash = '#' + page + '/' + param;
    } else {
      window.location.hash = '#' + page;
    }
  }

  function render() {
    if (!data) return;
    var route = getRoute();
    var page = route.page;
    var param = route.param;

    setActiveNav(page);

    switch (page) {
      case 'dashboard':
        updateBreadcrumb('dashboard');
        renderDashboard();
        break;
      case 'skills':
        updateBreadcrumb('skills');
        renderSkills();
        break;
      case 'skill-detail':
        updateBreadcrumb('skill-detail', decodeURIComponent(param));
        renderSkillDetail(decodeURIComponent(param));
        break;
      case 'hooks':
        updateBreadcrumb('hooks');
        renderHooks();
        break;
      case 'configs':
        updateBreadcrumb('configs');
        renderConfigs();
        break;
      case 'memory':
        updateBreadcrumb('memory');
        renderMemory();
        break;
      case 'verify':
        updateBreadcrumb('verify');
        renderVerify();
        break;
      case 'scripts':
        updateBreadcrumb('scripts');
        renderScripts();
        break;
      default:
        updateBreadcrumb('dashboard');
        renderDashboard();
        break;
    }
  }

  window.addEventListener('hashchange', render);

  // ===== Event Delegation =====
  document.addEventListener('click', function (e) {
    // Logo click
    if (e.target.closest('#logo-link')) {
      navigate('dashboard');
      return;
    }

    // Breadcrumb links
    var bcLink = e.target.closest('.bc-link[data-page]');
    if (bcLink) {
      navigate(bcLink.getAttribute('data-page'));
      return;
    }

    // Nav items
    var navItem = e.target.closest('.nav-item[data-page]');
    if (navItem) {
      var page = navItem.getAttribute('data-page');
      navigate(page);
      // Toggle skills sub-nav
      if (page === 'skills') {
        var sub = document.getElementById('skills-sub');
        var chev = document.getElementById('skills-chevron');
        sub.classList.toggle('open');
        if (chev) chev.classList.toggle('open');
      }
      return;
    }

    // Sub nav filter items
    var subItem = e.target.closest('.nav-sub-item[data-filter]');
    if (subItem) {
      currentFilter = subItem.getAttribute('data-filter');
      navigate('skills');
      return;
    }

    // Filter chips
    var chip = e.target.closest('.filter-chip[data-filter]');
    if (chip) {
      currentFilter = chip.getAttribute('data-filter');
      renderSkills();
      return;
    }

    // Skill rows -> detail
    var skillRow = e.target.closest('.skill-row[data-skill-name]');
    if (skillRow) {
      var name = skillRow.getAttribute('data-skill-name');
      navigate('skill-detail', encodeURIComponent(name));
      return;
    }

    // Back to skills
    if (e.target.id === 'backToSkills' || e.target.closest('#backToSkills')) {
      navigate('skills');
      return;
    }

    // Stat card navigation
    var statCard = e.target.closest('.stat-card[data-navigate]');
    if (statCard) {
      navigate(statCard.getAttribute('data-navigate'));
      return;
    }

    // Hook card toggle
    var hookCard = e.target.closest('.hook-card');
    if (hookCard) {
      var hookContent = hookCard.querySelector('.hook-content');
      if (hookContent) hookContent.classList.toggle('open');
      return;
    }

    // Config card toggle
    var configCard = e.target.closest('.config-card');
    if (configCard) {
      var configContent = configCard.querySelector('.config-content');
      if (configContent) configContent.classList.toggle('open');
      return;
    }

    // Verify tabs
    var verifyTab = e.target.closest('.verify-tab[data-verify-tab]');
    if (verifyTab) {
      currentVerifyTab = verifyTab.getAttribute('data-verify-tab');
      // Update active tab
      var allTabs = document.querySelectorAll('.verify-tab');
      for (var i = 0; i < allTabs.length; i++) {
        allTabs[i].classList.remove('active');
      }
      verifyTab.classList.add('active');
      renderVerifyItems(null);
      return;
    }
  });

  // ===== Init =====
  loadData(function () {
    updateSidebar();
    render();
  });

})();
