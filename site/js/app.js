/* ===== Claude Code Dashboard SPA ===== */

(function () {
  'use strict';

  var data = null;
  var currentFilter = 'all';
  var currentVerifyTab = 'pending';
  var memoryData = null;
  var MEMORY_GIST_ID = '';

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

    // Title row with create button
    var titleRow = el('div', { className: 'page-title-row' });
    titleRow.appendChild(el('div', { className: 'page-title', textContent: 'Skills' }));
    if (typeof Editor !== 'undefined') {
      var skillTemplate = '---\nname: \ndescription: \nversion: 1.0.0\n---\n\n# Skill Name\n';
      titleRow.appendChild(Editor.createCreateBtn('skills', skillTemplate, 'my-skill/SKILL.md'));
    }
    content.appendChild(titleRow);
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
      if (typeof Editor !== 'undefined' && skill.file) {
        var actions = el('span', { className: 'crud-actions' });
        actions.appendChild(Editor.createEditBtn(skill.file));
        actions.appendChild(Editor.createDeleteBtn(skill.file));
        row.appendChild(actions);
      }
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
    if (typeof Editor !== 'undefined' && skill.file) {
      var detailActions = el('span', { className: 'crud-actions' });
      detailActions.appendChild(Editor.createEditBtn(skill.file));
      detailActions.appendChild(Editor.createDeleteBtn(skill.file));
      meta.appendChild(detailActions);
    }
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

    var hookTitleRow = el('div', { className: 'page-title-row' });
    hookTitleRow.appendChild(el('div', { className: 'page-title', textContent: 'Hooks' }));
    if (typeof Editor !== 'undefined') {
      var hookTemplate = '{\n  "hooks": {}\n}';
      hookTitleRow.appendChild(Editor.createCreateBtn('hooks', hookTemplate, 'my-hook.json'));
    }
    content.appendChild(hookTitleRow);
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

      if (typeof Editor !== 'undefined' && hook.file) {
        var hookActions = el('span', { className: 'crud-actions' });
        hookActions.appendChild(Editor.createEditBtn(hook.file));
        hookActions.appendChild(Editor.createDeleteBtn(hook.file));
        header.appendChild(hookActions);
      }

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

    var configTitleRow = el('div', { className: 'page-title-row' });
    configTitleRow.appendChild(el('div', { className: 'page-title', textContent: 'Configs' }));
    if (typeof Editor !== 'undefined') {
      var configTemplate = '{}';
      configTitleRow.appendChild(Editor.createCreateBtn('configs', configTemplate, 'my-config.json'));
    }
    content.appendChild(configTitleRow);
    content.appendChild(el('div', { className: 'page-desc' },
      data.configs.length + ' configuration files'));

    data.configs.forEach(function (config) {
      var card = el('div', { className: 'config-card' });

      var header = el('div', { className: 'config-card-header' });
      header.appendChild(el('div', { className: 'cc-name', textContent: config.name }));
      header.appendChild(el('div', { className: 'cc-path', textContent: config.file }));
      if (typeof Editor !== 'undefined' && config.file) {
        var configActions = el('div', { className: 'crud-actions' });
        configActions.appendChild(Editor.createEditBtn(config.file));
        configActions.appendChild(Editor.createDeleteBtn(config.file));
        header.appendChild(configActions);
      }
      card.appendChild(header);

      // Meta tags for JSON configs
      if (config.meta && config.meta.keys) {
        var metaRow = el('div', { className: 'config-meta' });
        if (config.meta.model) {
          metaRow.appendChild(el('span', { className: 'config-tag tag-model', textContent: config.meta.model }));
        }
        if (config.meta.plugin_count > 0) {
          metaRow.appendChild(el('span', { className: 'config-tag tag-plugins', textContent: config.meta.plugin_count + ' plugins' }));
        }
        if (config.meta.hook_event_count > 0) {
          metaRow.appendChild(el('span', { className: 'config-tag tag-hooks', textContent: config.meta.hook_event_count + ' hook events' }));
        }
        metaRow.appendChild(el('span', { className: 'config-tag', textContent: config.meta.keys + ' top-level keys' }));
        card.appendChild(metaRow);
      }

      // Expandable content
      var contentDiv = el('div', { className: 'config-content collapsed' });
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

      // Toggle expand/collapse
      var toggleBtn = el('button', { className: 'config-toggle', textContent: 'Show content' });
      toggleBtn.addEventListener('click', function () {
        var isCollapsed = contentDiv.classList.contains('collapsed');
        if (isCollapsed) {
          contentDiv.classList.remove('collapsed');
          toggleBtn.textContent = 'Hide content';
        } else {
          contentDiv.classList.add('collapsed');
          toggleBtn.textContent = 'Show content';
        }
      });
      card.appendChild(toggleBtn);

      content.appendChild(card);
    });
  }

  // --- Memory ---
  function fetchMemoryFromGist(token, callback) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', 'https://api.github.com/gists/' + MEMORY_GIST_ID);
    xhr.setRequestHeader('Authorization', 'Bearer ' + token);
    xhr.setRequestHeader('Accept', 'application/vnd.github+json');
    xhr.onload = function () {
      if (xhr.status === 200) {
        try {
          var gist = JSON.parse(xhr.responseText);
          var fileContent = gist.files['memory-data.json'].content;
          memoryData = JSON.parse(fileContent);
          callback(null, memoryData);
        } catch (e) {
          callback('Failed to parse memory data: ' + e.message);
        }
      } else {
        callback('Gist API returned status ' + xhr.status);
      }
    };
    xhr.onerror = function () {
      callback('Network error fetching Gist');
    };
    xhr.send();
  }

  function renderMemoryContent(contentEl) {
    var stats = memoryData.stats || {};
    var memories = memoryData.memories || [];

    // Stats row
    var statsGrid = el('div', { className: 'stat-grid' });
    var typeColors = {
      feedback: 'color-yellow',
      project: 'color-accent',
      reference: 'color-purple',
      user: 'color-green'
    };
    ['feedback', 'project', 'reference', 'user'].forEach(function (type) {
      var card = el('div', { className: 'stat-card' });
      card.appendChild(el('div', { className: 'stat-label', textContent: type.charAt(0).toUpperCase() + type.slice(1) }));
      card.appendChild(el('div', { className: 'stat-value ' + (typeColors[type] || 'color-accent'), textContent: String(stats[type] || 0) }));
      card.appendChild(el('div', { className: 'stat-sub', textContent: 'memories' }));
      statsGrid.appendChild(card);
    });
    contentEl.appendChild(statsGrid);

    // Table
    var table = el('div', { className: 'verify-list' });
    memories.forEach(function (mem) {
      var item = el('div', { className: 'verify-item' });
      var header = el('div', { className: 'vi-header' });

      // Type badge
      var badgeClass = 'event-badge ';
      if (mem.type === 'feedback') badgeClass += 'event-notification';
      else if (mem.type === 'project') badgeClass += 'event-pretooluse';
      else if (mem.type === 'reference') badgeClass += 'event-default';
      else badgeClass += 'event-stop';
      header.appendChild(el('span', { className: badgeClass, textContent: mem.type || 'unknown' }));

      header.appendChild(el('span', { className: 'vi-title', textContent: mem.name || '(unnamed)' }));
      if (mem.file) {
        header.appendChild(el('span', { className: 'vi-date', textContent: mem.file }));
      }
      item.appendChild(header);

      if (mem.description) {
        var descDiv = el('div', { className: 'vi-detail' });
        descDiv.appendChild(el('div', { textContent: mem.description }));
        item.appendChild(descDiv);
      }

      // Expandable content area
      var expandDiv = el('div', { className: 'hook-content' });
      if (mem.content && typeof marked !== 'undefined') {
        var rendered = document.createElement('div');
        rendered.className = 'sd-content';
        rendered.innerHTML = marked.parse(mem.content);
        expandDiv.appendChild(rendered);
      } else if (mem.content) {
        var pre = document.createElement('pre');
        pre.textContent = mem.content;
        expandDiv.appendChild(pre);
      }
      item.appendChild(expandDiv);

      item.addEventListener('click', function () {
        expandDiv.classList.toggle('open');
      });
      item.style.cursor = 'pointer';

      table.appendChild(item);
    });
    contentEl.appendChild(table);
  }

  function renderMemory() {
    var content = document.getElementById('content');
    while (content.firstChild) content.removeChild(content.firstChild);

    content.appendChild(el('div', { className: 'page-title', textContent: 'Memory' }));
    content.appendChild(el('div', { className: 'page-desc' },
      'Persistent cross-session memory \u2014 private data requires authentication'));

    // Check for token in URL param
    var urlParams = new URLSearchParams(window.location.search);
    var urlToken = urlParams.get('token');
    if (urlToken) {
      sessionStorage.setItem('memory_token', urlToken);
      // Clean URL
      var cleanUrl = window.location.pathname + window.location.hash;
      window.history.replaceState(null, '', cleanUrl);
    }

    var token = sessionStorage.getItem('memory_token');

    // If we have token and data already loaded, render content
    if (token && memoryData) {
      renderMemoryContent(content);
      return;
    }

    // If we have token but no data, fetch from Gist
    if (token && !memoryData) {
      if (!MEMORY_GIST_ID) {
        var errMsg = el('div', { className: 'auth-message visible', textContent: 'MEMORY_GIST_ID not configured. Run export-memory.sh first, then set the ID in app.js.' });
        errMsg.style.display = 'block';
        errMsg.style.maxWidth = '480px';
        errMsg.style.margin = '40px auto';
        content.appendChild(errMsg);
        sessionStorage.removeItem('memory_token');
        return;
      }

      var loading = el('div', { className: 'page-desc', textContent: 'Loading memory data...' });
      loading.style.textAlign = 'center';
      loading.style.marginTop = '40px';
      content.appendChild(loading);

      fetchMemoryFromGist(token, function (err) {
        if (err) {
          sessionStorage.removeItem('memory_token');
          memoryData = null;
          // Re-render to show auth gate with error
          renderMemory();
        } else {
          renderMemory();
        }
      });
      return;
    }

    // No token — show auth gate
    var gate = el('div', { className: 'auth-gate' });
    gate.appendChild(el('div', { className: 'lock-icon', textContent: '\uD83D\uDD12' }));
    gate.appendChild(el('h2', { textContent: 'Private Memory Data' }));

    var desc = el('p');
    desc.appendChild(document.createTextNode('Memory data is stored in a private GitHub Gist.'));
    desc.appendChild(document.createElement('br'));
    desc.appendChild(document.createTextNode('Enter your GitHub token to view full content.'));
    gate.appendChild(desc);

    var inputRow = el('div', { className: 'auth-input' });
    var input = el('input', { type: 'password', placeholder: 'Enter GitHub token...' });
    inputRow.appendChild(input);
    var btn = el('button', { className: 'auth-btn', textContent: 'Unlock' });
    inputRow.appendChild(btn);
    gate.appendChild(inputRow);

    var msg = el('div', { className: 'auth-message' });
    gate.appendChild(msg);

    gate.appendChild(el('p', { className: 'auth-note', textContent: 'Token is stored in sessionStorage only (cleared on tab close)' }));

    btn.addEventListener('click', function () {
      var tokenValue = input.value.trim();
      if (!tokenValue) {
        msg.textContent = 'Please enter a token';
        msg.classList.add('visible');
        return;
      }
      if (!MEMORY_GIST_ID) {
        msg.textContent = 'MEMORY_GIST_ID not configured. Run export-memory.sh first, then set the ID in app.js.';
        msg.classList.add('visible');
        return;
      }
      sessionStorage.setItem('memory_token', tokenValue);
      renderMemory();
    });

    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') btn.click();
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

  // ===== Global Search =====
  var searchBox = document.getElementById('searchBox');

  function collectSearchResults(query) {
    var results = [];
    var q = query.toLowerCase();

    if (data.skills) {
      data.skills.forEach(function (s) {
        var name = (s.name || '').toLowerCase();
        var desc = (s.description || '').toLowerCase();
        if (name.indexOf(q) !== -1 || desc.indexOf(q) !== -1) {
          results.push({ type: 'skill', name: s.name, description: s.description || '', hash: '#skill-detail/' + encodeURIComponent(s.name) });
        }
      });
    }

    if (data.hooks) {
      data.hooks.forEach(function (h) {
        var name = (h.name || '').toLowerCase();
        var desc = (h.description || '').toLowerCase();
        if (name.indexOf(q) !== -1 || desc.indexOf(q) !== -1) {
          results.push({ type: 'hook', name: h.name, description: h.description || '', hash: '#hooks' });
        }
      });
    }

    if (data.configs) {
      data.configs.forEach(function (c) {
        var name = (c.name || '').toLowerCase();
        if (name.indexOf(q) !== -1) {
          results.push({ type: 'config', name: c.name, description: '', hash: '#configs' });
        }
      });
    }

    if (data.scripts) {
      data.scripts.forEach(function (s) {
        var name = (s.name || '').toLowerCase();
        var desc = (s.description || '').toLowerCase();
        if (name.indexOf(q) !== -1 || desc.indexOf(q) !== -1) {
          results.push({ type: 'script', name: s.name, description: s.description || '', hash: '#scripts' });
        }
      });
    }

    return results.slice(0, 10);
  }

  function hideSearchResults() {
    var existing = document.querySelector('.search-dropdown');
    if (existing) {
      existing.parentNode.removeChild(existing);
    }
  }

  function showSearchResults(query) {
    hideSearchResults();
    if (!data || query.length < 2) return;

    var results = collectSearchResults(query);
    var dropdown = document.createElement('div');
    dropdown.className = 'search-dropdown';

    if (results.length === 0) {
      var noResults = document.createElement('div');
      noResults.className = 'search-no-results';
      noResults.textContent = 'No results for "' + query + '"';
      dropdown.appendChild(noResults);
    } else {
      // Group by type
      var groups = {};
      results.forEach(function (r) {
        if (!groups[r.type]) groups[r.type] = [];
        groups[r.type].push(r);
      });

      var typeOrder = ['skill', 'hook', 'config', 'script'];
      typeOrder.forEach(function (type) {
        var items = groups[type];
        if (!items) return;

        var label = document.createElement('div');
        label.className = 'search-group-label';
        label.textContent = type + 's';
        dropdown.appendChild(label);

        items.forEach(function (item) {
          var row = document.createElement('div');
          row.className = 'search-result-item';

          var badge = document.createElement('span');
          badge.className = 'sr-type-badge type-' + item.type;
          badge.textContent = item.type;
          row.appendChild(badge);

          var nameSpan = document.createElement('span');
          nameSpan.className = 'sr-result-name';
          nameSpan.textContent = item.name;
          row.appendChild(nameSpan);

          if (item.description) {
            var descSpan = document.createElement('span');
            descSpan.className = 'sr-result-desc';
            var desc = item.description;
            if (desc.length > 50) desc = desc.substring(0, 50) + '...';
            descSpan.textContent = desc;
            row.appendChild(descSpan);
          }

          row.addEventListener('mousedown', function (e) {
            e.preventDefault();
            window.location.hash = item.hash;
            searchBox.value = '';
            hideSearchResults();
            searchBox.blur();
          });

          dropdown.appendChild(row);
        });
      });
    }

    var topbar = document.querySelector('.topbar');
    topbar.appendChild(dropdown);
  }

  searchBox.addEventListener('input', function () {
    showSearchResults(searchBox.value.trim());
  });

  searchBox.addEventListener('focus', function () {
    if (searchBox.value.trim().length >= 2) {
      showSearchResults(searchBox.value.trim());
    }
  });

  searchBox.addEventListener('blur', function () {
    setTimeout(hideSearchResults, 200);
  });

  document.addEventListener('keydown', function (e) {
    // Ctrl+K or Cmd+K
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault();
      searchBox.focus();
      searchBox.select();
    }
    // Escape
    if (e.key === 'Escape') {
      searchBox.blur();
      hideSearchResults();
    }
  });

  // ===== Init =====
  loadData(function () {
    updateSidebar();
    render();
  });

})();
