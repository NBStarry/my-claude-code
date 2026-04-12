/* ===== CRUD Editor Module ===== */
/* Provides edit/delete/create capabilities via the GitHub Contents API */

var Editor = (function () {
  'use strict';

  var OWNER = 'NBStarry';
  var REPO = 'my-claude-code';
  var BRANCH = 'dev';
  var API_BASE = 'https://api.github.com/repos/' + OWNER + '/' + REPO + '/contents/';

  // ===== Token Management =====

  function getToken() {
    return sessionStorage.getItem('github_token');
  }

  function setToken(token) {
    sessionStorage.setItem('github_token', token);
  }

  function ensureToken(callback) {
    var token = getToken();
    if (token) {
      callback(token);
      return;
    }
    showTokenModal(function (newToken) {
      if (newToken) {
        setToken(newToken);
        callback(newToken);
      }
    });
  }

  // ===== Token Modal =====

  function showTokenModal(callback) {
    var overlay = document.createElement('div');
    overlay.className = 'token-modal';

    var box = document.createElement('div');
    box.className = 'token-modal-box';

    var title = document.createElement('h3');
    title.textContent = 'GitHub Token Required';
    box.appendChild(title);

    var desc = document.createElement('p');
    desc.textContent = 'Enter a GitHub personal access token with repo scope to edit files on the dev branch.';
    box.appendChild(desc);

    var input = document.createElement('input');
    input.type = 'password';
    input.placeholder = 'ghp_xxxxxxxxxxxxxxxxxxxx';
    input.className = 'token-modal-input';
    box.appendChild(input);

    var note = document.createElement('p');
    note.className = 'token-modal-note';
    note.textContent = 'Token is stored in sessionStorage only (cleared on tab close).';
    box.appendChild(note);

    var btnRow = document.createElement('div');
    btnRow.className = 'token-modal-buttons';

    var cancelBtn = document.createElement('button');
    cancelBtn.className = 'btn-cancel';
    cancelBtn.textContent = 'Cancel';
    cancelBtn.addEventListener('click', function () {
      document.body.removeChild(overlay);
      callback(null);
    });
    btnRow.appendChild(cancelBtn);

    var confirmBtn = document.createElement('button');
    confirmBtn.className = 'btn-confirm';
    confirmBtn.textContent = 'Save Token';
    confirmBtn.addEventListener('click', function () {
      var val = input.value.trim();
      if (val) {
        document.body.removeChild(overlay);
        callback(val);
      }
    });
    btnRow.appendChild(confirmBtn);

    box.appendChild(btnRow);
    overlay.appendChild(box);
    document.body.appendChild(overlay);
    input.focus();

    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') confirmBtn.click();
      if (e.key === 'Escape') cancelBtn.click();
    });
  }

  // ===== GitHub API Helpers =====

  function apiRequest(method, path, body, callback) {
    var token = getToken();
    if (!token) {
      callback('No token available');
      return;
    }
    var xhr = new XMLHttpRequest();
    var url = API_BASE + path;
    if (method === 'GET') {
      url += (url.indexOf('?') === -1 ? '?' : '&') + 'ref=' + BRANCH;
    }
    xhr.open(method, url);
    xhr.setRequestHeader('Authorization', 'Bearer ' + token);
    xhr.setRequestHeader('Accept', 'application/vnd.github+json');
    if (body) {
      xhr.setRequestHeader('Content-Type', 'application/json');
    }
    xhr.onload = function () {
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          callback(null, JSON.parse(xhr.responseText));
        } catch (e) {
          callback(null, xhr.responseText);
        }
      } else {
        var errMsg = 'API error ' + xhr.status;
        try {
          var errData = JSON.parse(xhr.responseText);
          if (errData.message) errMsg += ': ' + errData.message;
        } catch (e) { /* ignore */ }
        callback(errMsg);
      }
    };
    xhr.onerror = function () {
      callback('Network error');
    };
    xhr.send(body ? JSON.stringify(body) : null);
  }

  function fetchFile(filePath, callback) {
    apiRequest('GET', filePath, null, function (err, data) {
      if (err) {
        callback(err);
        return;
      }
      var content = '';
      if (data.content) {
        content = decodeBase64(data.content);
      }
      callback(null, { content: content, sha: data.sha, path: data.path });
    });
  }

  function updateFile(filePath, content, sha, message, callback) {
    var body = {
      message: message,
      content: encodeBase64(content),
      branch: BRANCH
    };
    if (sha) {
      body.sha = sha;
    }
    apiRequest('PUT', filePath, body, callback);
  }

  function deleteFile(filePath, sha, message, callback) {
    var token = getToken();
    if (!token) {
      callback('No token available');
      return;
    }
    var xhr = new XMLHttpRequest();
    xhr.open('DELETE', API_BASE + filePath);
    xhr.setRequestHeader('Authorization', 'Bearer ' + token);
    xhr.setRequestHeader('Accept', 'application/vnd.github+json');
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.onload = function () {
      if (xhr.status >= 200 && xhr.status < 300) {
        callback(null);
      } else {
        var errMsg = 'API error ' + xhr.status;
        try {
          var errData = JSON.parse(xhr.responseText);
          if (errData.message) errMsg += ': ' + errData.message;
        } catch (e) { /* ignore */ }
        callback(errMsg);
      }
    };
    xhr.onerror = function () {
      callback('Network error');
    };
    xhr.send(JSON.stringify({
      message: message,
      sha: sha,
      branch: BRANCH
    }));
  }

  // ===== Base64 Helpers =====

  function encodeBase64(str) {
    return btoa(unescape(encodeURIComponent(str)));
  }

  function decodeBase64(encoded) {
    // GitHub returns base64 with newlines
    var cleaned = encoded.replace(/\n/g, '');
    return decodeURIComponent(escape(atob(cleaned)));
  }

  // ===== Simple Diff =====

  function simpleDiff(oldText, newText) {
    var oldLines = oldText.split('\n');
    var newLines = newText.split('\n');
    var result = [];
    var maxLen = Math.max(oldLines.length, newLines.length);

    for (var i = 0; i < maxLen; i++) {
      var oldLine = i < oldLines.length ? oldLines[i] : undefined;
      var newLine = i < newLines.length ? newLines[i] : undefined;

      if (oldLine === newLine) {
        result.push({ type: 'same', text: oldLine });
      } else {
        if (oldLine !== undefined) result.push({ type: 'removed', text: oldLine });
        if (newLine !== undefined) result.push({ type: 'added', text: newLine });
      }
    }
    return result;
  }

  // ===== Editor Modal =====

  function showEditorModal(filePath, originalContent, sha, isNew) {
    var overlay = document.createElement('div');
    overlay.className = 'editor-modal';

    var container = document.createElement('div');
    container.className = 'editor-container';

    // Top bar
    var topbar = document.createElement('div');
    topbar.className = 'editor-topbar';

    var pathLabel = document.createElement('span');
    pathLabel.className = 'editor-path';
    pathLabel.textContent = filePath;
    topbar.appendChild(pathLabel);

    var btnGroup = document.createElement('div');
    btnGroup.className = 'editor-btn-group';

    var saveBtn = document.createElement('button');
    saveBtn.className = 'btn-confirm';
    saveBtn.textContent = 'Save';
    btnGroup.appendChild(saveBtn);

    var cancelBtn = document.createElement('button');
    cancelBtn.className = 'btn-cancel';
    cancelBtn.textContent = 'Cancel';
    btnGroup.appendChild(cancelBtn);

    topbar.appendChild(btnGroup);
    container.appendChild(topbar);

    // Editor body (split view)
    var editorBody = document.createElement('div');
    editorBody.className = 'editor-body';

    var textarea = document.createElement('textarea');
    textarea.className = 'editor-textarea';
    textarea.value = originalContent;
    textarea.spellcheck = false;
    editorBody.appendChild(textarea);

    var preview = document.createElement('div');
    preview.className = 'editor-preview';
    editorBody.appendChild(preview);

    container.appendChild(editorBody);
    overlay.appendChild(container);
    document.body.appendChild(overlay);

    // Live preview - rendered from our own repo content (safe, same pattern as app.js renderMarkdown)
    function updatePreview() {
      var text = textarea.value;
      if (typeof marked !== 'undefined') {
        while (preview.firstChild) preview.removeChild(preview.firstChild);
        var rendered = document.createElement('div');
        rendered.className = 'sd-content';
        rendered.innerHTML = marked.parse(text);
        preview.appendChild(rendered);
      } else {
        preview.textContent = text;
      }
    }
    updatePreview();
    textarea.addEventListener('input', updatePreview);
    textarea.focus();

    // Cancel
    cancelBtn.addEventListener('click', function () {
      document.body.removeChild(overlay);
    });

    // Save -> show diff
    saveBtn.addEventListener('click', function () {
      var newContent = textarea.value;
      if (newContent === originalContent && !isNew) {
        document.body.removeChild(overlay);
        return;
      }
      showDiffView(overlay, container, filePath, originalContent, newContent, sha, isNew);
    });

    // Escape to close
    overlay.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') {
        document.body.removeChild(overlay);
      }
    });
  }

  // ===== Diff View =====

  function showDiffView(overlay, container, filePath, oldContent, newContent, sha, isNew) {
    // Replace container content with diff view
    while (container.firstChild) container.removeChild(container.firstChild);

    // Top bar
    var topbar = document.createElement('div');
    topbar.className = 'editor-topbar';

    var pathLabel = document.createElement('span');
    pathLabel.className = 'editor-path';
    pathLabel.textContent = 'Review changes: ' + filePath;
    topbar.appendChild(pathLabel);

    var btnGroup = document.createElement('div');
    btnGroup.className = 'editor-btn-group';

    var commitBtn = document.createElement('button');
    commitBtn.className = 'btn-confirm';
    commitBtn.textContent = 'Confirm Commit';
    btnGroup.appendChild(commitBtn);

    var backBtn = document.createElement('button');
    backBtn.className = 'btn-cancel';
    backBtn.textContent = 'Back to Edit';
    btnGroup.appendChild(backBtn);

    topbar.appendChild(btnGroup);
    container.appendChild(topbar);

    // Commit message input
    var msgRow = document.createElement('div');
    msgRow.className = 'editor-commit-row';

    var msgLabel = document.createElement('label');
    msgLabel.textContent = 'Commit message:';
    msgLabel.className = 'editor-commit-label';
    msgRow.appendChild(msgLabel);

    var msgInput = document.createElement('input');
    msgInput.type = 'text';
    msgInput.className = 'editor-commit-input';
    var fileName = filePath.split('/').pop();
    msgInput.value = isNew ? 'create: ' + fileName : 'update: ' + fileName;
    msgRow.appendChild(msgInput);

    container.appendChild(msgRow);

    // Diff display
    var diffContainer = document.createElement('div');
    diffContainer.className = 'diff-view';

    var diffLines = simpleDiff(isNew ? '' : oldContent, newContent);
    diffLines.forEach(function (line) {
      var lineEl = document.createElement('div');
      if (line.type === 'added') {
        lineEl.className = 'diff-added';
        lineEl.textContent = '+ ' + line.text;
      } else if (line.type === 'removed') {
        lineEl.className = 'diff-removed';
        lineEl.textContent = '- ' + line.text;
      } else {
        lineEl.className = 'diff-same';
        lineEl.textContent = '  ' + line.text;
      }
      diffContainer.appendChild(lineEl);
    });

    container.appendChild(diffContainer);

    // Back to edit
    backBtn.addEventListener('click', function () {
      document.body.removeChild(overlay);
      showEditorModal(filePath, newContent, sha, isNew);
    });

    // Confirm commit
    commitBtn.addEventListener('click', function () {
      var msg = msgInput.value.trim();
      if (!msg) {
        msgInput.style.borderColor = 'var(--red)';
        return;
      }
      commitBtn.disabled = true;
      commitBtn.textContent = 'Committing...';

      updateFile(filePath, newContent, sha || null, msg, function (err) {
        if (err) {
          commitBtn.textContent = 'Error: ' + err;
          commitBtn.disabled = false;
        } else {
          document.body.removeChild(overlay);
          showSuccessMessage('Changes committed to dev. Dashboard will update after the next GitHub Actions build.');
        }
      });
    });
  }

  // ===== Delete Confirmation =====

  function showDeleteConfirm(filePath, sha) {
    var overlay = document.createElement('div');
    overlay.className = 'confirm-modal';

    var box = document.createElement('div');
    box.className = 'confirm-modal-box';

    var title = document.createElement('h3');
    title.textContent = 'Confirm Delete';
    box.appendChild(title);

    var fileName = filePath.split('/').pop();

    var desc = document.createElement('p');
    desc.textContent = '\u786E\u5B9A\u8981\u5220\u9664 ' + fileName + '\uFF1F\u6B64\u64CD\u4F5C\u5C06\u76F4\u63A5\u63D0\u4EA4\u5230 dev \u5206\u652F\u3002';
    box.appendChild(desc);

    var msgLabel = document.createElement('label');
    msgLabel.textContent = 'Commit message:';
    msgLabel.className = 'editor-commit-label';
    box.appendChild(msgLabel);

    var msgInput = document.createElement('input');
    msgInput.type = 'text';
    msgInput.className = 'editor-commit-input';
    msgInput.value = 'delete: ' + fileName;
    box.appendChild(msgInput);

    var btnRow = document.createElement('div');
    btnRow.className = 'token-modal-buttons';

    var cancelBtn = document.createElement('button');
    cancelBtn.className = 'btn-cancel';
    cancelBtn.textContent = 'Cancel';
    cancelBtn.addEventListener('click', function () {
      document.body.removeChild(overlay);
    });
    btnRow.appendChild(cancelBtn);

    var confirmBtn = document.createElement('button');
    confirmBtn.className = 'btn-confirm btn-danger';
    confirmBtn.textContent = 'Confirm Delete';
    confirmBtn.addEventListener('click', function () {
      var msg = msgInput.value.trim();
      if (!msg) {
        msgInput.style.borderColor = 'var(--red)';
        return;
      }
      confirmBtn.disabled = true;
      confirmBtn.textContent = 'Deleting...';

      deleteFile(filePath, sha, msg, function (err) {
        if (err) {
          confirmBtn.textContent = 'Error: ' + err;
          confirmBtn.disabled = false;
        } else {
          document.body.removeChild(overlay);
          showSuccessMessage('File deleted from dev. Dashboard will update after the next GitHub Actions build.');
        }
      });
    });
    btnRow.appendChild(confirmBtn);

    box.appendChild(btnRow);
    overlay.appendChild(box);
    document.body.appendChild(overlay);

    msgInput.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') cancelBtn.click();
    });
  }

  // ===== Success Message =====

  function showSuccessMessage(message) {
    var toast = document.createElement('div');
    toast.className = 'editor-toast';
    toast.textContent = message;
    document.body.appendChild(toast);
    setTimeout(function () {
      toast.classList.add('editor-toast-fade');
      setTimeout(function () {
        if (toast.parentNode) document.body.removeChild(toast);
      }, 500);
    }, 4000);
  }

  // ===== Create Button Helper =====

  function createNamePrompt(directory, template, defaultName, callback) {
    var overlay = document.createElement('div');
    overlay.className = 'confirm-modal';

    var box = document.createElement('div');
    box.className = 'confirm-modal-box';

    var title = document.createElement('h3');
    title.textContent = 'Create New File';
    box.appendChild(title);

    var desc = document.createElement('p');
    desc.textContent = 'Enter a file name for the new file in ' + directory + '/';
    box.appendChild(desc);

    var input = document.createElement('input');
    input.type = 'text';
    input.className = 'editor-commit-input';
    input.value = defaultName || '';
    input.placeholder = 'my-file-name';
    box.appendChild(input);

    var btnRow = document.createElement('div');
    btnRow.className = 'token-modal-buttons';

    var cancelBtn = document.createElement('button');
    cancelBtn.className = 'btn-cancel';
    cancelBtn.textContent = 'Cancel';
    cancelBtn.addEventListener('click', function () {
      document.body.removeChild(overlay);
    });
    btnRow.appendChild(cancelBtn);

    var confirmBtn = document.createElement('button');
    confirmBtn.className = 'btn-confirm';
    confirmBtn.textContent = 'Create';
    confirmBtn.addEventListener('click', function () {
      var name = input.value.trim();
      if (name) {
        document.body.removeChild(overlay);
        callback(name);
      }
    });
    btnRow.appendChild(confirmBtn);

    box.appendChild(btnRow);
    overlay.appendChild(box);
    document.body.appendChild(overlay);
    input.focus();

    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') confirmBtn.click();
      if (e.key === 'Escape') cancelBtn.click();
    });
  }

  // ===== Public API =====

  function edit(filePath) {
    ensureToken(function () {
      fetchFile(filePath, function (err, fileData) {
        if (err) {
          showSuccessMessage('Error loading file: ' + err);
          return;
        }
        showEditorModal(filePath, fileData.content, fileData.sha, false);
      });
    });
  }

  function create(directory, template, defaultName) {
    ensureToken(function () {
      createNamePrompt(directory, template, defaultName, function (name) {
        var fullPath = directory + '/' + name;
        showEditorModal(fullPath, template, null, true);
      });
    });
  }

  function remove(filePath) {
    ensureToken(function () {
      // First fetch to get sha
      fetchFile(filePath, function (err, fileData) {
        if (err) {
          showSuccessMessage('Error loading file: ' + err);
          return;
        }
        showDeleteConfirm(filePath, fileData.sha);
      });
    });
  }

  function init() {
    // Nothing needed on init for now
  }

  // ===== Button Factory =====

  function createEditBtn(filePath) {
    var btn = document.createElement('button');
    btn.className = 'btn-edit';
    btn.textContent = 'Edit';
    btn.title = 'Edit file';
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      edit(filePath);
    });
    return btn;
  }

  function createDeleteBtn(filePath) {
    var btn = document.createElement('button');
    btn.className = 'btn-delete';
    btn.textContent = 'Del';
    btn.title = 'Delete file';
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      remove(filePath);
    });
    return btn;
  }

  function createCreateBtn(directory, template, defaultName) {
    var btn = document.createElement('button');
    btn.className = 'btn-create';
    btn.textContent = '+';
    btn.title = 'Create new file';
    btn.addEventListener('click', function (e) {
      e.stopPropagation();
      create(directory, template, defaultName);
    });
    return btn;
  }

  return {
    init: init,
    edit: edit,
    create: create,
    remove: remove,
    createEditBtn: createEditBtn,
    createDeleteBtn: createDeleteBtn,
    createCreateBtn: createCreateBtn
  };

})();
