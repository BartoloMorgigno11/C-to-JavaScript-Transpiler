const MIN_TEXTAREA_HEIGHT = 180;
const registeredTextareas = new WeakSet();

function adjustTextareaHeight(el) {
  if (!el) return;
  el.style.height = "auto";
  const min = Number(el.dataset.minHeight || MIN_TEXTAREA_HEIGHT);
  el.style.height = `${Math.max(el.scrollHeight, min)}px`;
}

function registerTextarea(el) {
  if (!el || registeredTextareas.has(el)) {
    return;
  }
  if (!el.dataset.minHeight) {
    el.dataset.minHeight = MIN_TEXTAREA_HEIGHT;
  }
  adjustTextareaHeight(el);
  el.addEventListener("input", () => adjustTextareaHeight(el));
  registeredTextareas.add(el);
}

document.querySelectorAll("textarea").forEach(registerTextarea);

function escapeHtml(text = "") {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

const buildBtn = document.querySelector("#build-btn");
const forceRebuildCheckbox = document.querySelector("#force-rebuild");
const buildLog = document.querySelector("#build-log");

const sourceTextarea = document.querySelector("#source");
const loadFileBtn = document.querySelector("#load-file-btn");
const fileInput = document.querySelector("#file-input");
const transpileBtn = document.querySelector("#transpile-btn");
const transpileStatus = document.querySelector("#transpile-status");
const jsOutput = document.querySelector("#js-output");
const astOutput = document.querySelector("#ast-output");

const testsBtn = document.querySelector("#tests-btn");
const testsStatus = document.querySelector("#tests-status");
const testsResults = document.querySelector("#tests-results");

async function callApi(url, body = {}) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || !data.ok) {
    const message = data.error || response.statusText || "Richiesta fallita";
    throw new Error(message);
  }
  return data;
}

function setStatus(element, message, kind = "") {
  element.textContent = message;
  element.className = kind ? `status ${kind}` : "status";
}

function renderTestResults(payload) {
  if (!testsResults) return;
  const okCases = payload?.ok ?? [];
  const errCases = payload?.error ?? [];

const buildBlock = (label, content, toneClass = "") => {
  if (!content) return "";
  return `
      <div class="text-block">
        <h4>${escapeHtml(label)}</h4>
        <textarea
          readonly
          class="test-textarea ${toneClass}"
          spellcheck="false"
          data-min-height="200"
        >${escapeHtml(content)}</textarea>
      </div>`;
};

  const renderCards = (cases, labels) => {
    if (!cases.length) {
      return `
        <div class="test-card empty-card">
          <p class="message">Esegui la suite per visualizzare i risultati.</p>
        </div>`;
    }

    return cases
      .map((item) => {
        const status = item.passed ? "OK" : "FALLITO";
        const badgeClass = item.passed ? "pass" : "fail";
        const title = escapeHtml(item.sourceName || `${item.name}.c`);
        const summary = item.message ? escapeHtml(item.message) : "&nbsp;";
        const toneClass = labels.toneClass || "";

        const blocks = [
          buildBlock(labels.sourceTitle, item.sourceContent, toneClass),
          buildBlock(labels.resultTitle, item.artifactContent, toneClass),
        ];

        if (labels.astTitle) {
          blocks.push(buildBlock(labels.astTitle, item.astContent, toneClass));
        }

        return `
          <div class="test-card ${badgeClass}">
            <div class="cell-header">
              <span class="title">${title}</span>
              <span class="badge ${badgeClass}">${status}</span>
            </div>
            <p class="message">${summary}</p>
            ${blocks.join("")}
          </div>`;
      })
      .join("");
  };

  testsResults.innerHTML = `
    <div class="tests-section">
      <h3>Suite OK</h3>
      <div class="tests-list">
        ${renderCards(okCases, {
          sourceTitle: "Sorgente C",
          resultTitle: "JavaScript generato",
          toneClass: "tone-success",
        })}
      </div>
    </div>
    <div class="tests-section">
      <h3>Suite Errori</h3>
      <div class="tests-list">
        ${renderCards(errCases, {
          sourceTitle: "Sorgente C",
          resultTitle: "Diagnostica parser",
          toneClass: "tone-error",
        })}
      </div>
    </div>`;

  testsResults.querySelectorAll("textarea").forEach(registerTextarea);
}

buildBtn?.addEventListener("click", async () => {
  buildBtn.disabled = true;
  setStatus(buildLog, "Compilazione del parser...");
  try {
    const data = await callApi("/api/build", {
      force: Boolean(forceRebuildCheckbox?.checked),
    });
    setStatus(buildLog, `Parser pronto: ${data.parser}`, "success");
  } catch (err) {
    setStatus(buildLog, err.message, "error");
  } finally {
    buildBtn.disabled = false;
  }
});

loadFileBtn?.addEventListener("click", () => fileInput?.click());

fileInput?.addEventListener("change", (event) => {
  const [file] = event.target.files ?? [];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    sourceTextarea.value = reader.result || "";
    adjustTextareaHeight(sourceTextarea);
    setStatus(
      transpileStatus,
      `Caricato ${file.name}. Clicca "Genera JavaScript" per transpilarlo.`,
      "success"
    );
  };
  reader.onerror = () => {
    setStatus(transpileStatus, "Impossibile leggere il file selezionato.", "error");
  };
  reader.readAsText(file, "utf-8");
});

transpileBtn?.addEventListener("click", async () => {
  const source = sourceTextarea.value.trim();
  if (!source) {
    setStatus(transpileStatus, "Inserisci del codice C prima.", "error");
    return;
  }
  transpileBtn.disabled = true;
  setStatus(transpileStatus, "Generazione...");
  jsOutput.value = "";
  astOutput.value = "";
  adjustTextareaHeight(jsOutput);
  adjustTextareaHeight(astOutput);
  try {
    const data = await callApi("/api/transpile", { source });
    setStatus(transpileStatus, "Transpilazione completata.", "success");
    jsOutput.value = data.js ?? "";
    astOutput.value = data.ast ?? "";
    adjustTextareaHeight(jsOutput);
    adjustTextareaHeight(astOutput);
  } catch (err) {
    setStatus(transpileStatus, err.message, "error");
  } finally {
    transpileBtn.disabled = false;
  }
});

testsBtn?.addEventListener("click", async () => {
  testsBtn.disabled = true;
  setStatus(testsStatus, "Esecuzione della suite di regressione...");
  try {
    const data = await callApi("/api/run-tests");
    const ok = data.exitCode === 0;
    setStatus(
      testsStatus,
      ok ? "Tutti i test superati." : "Alcuni test non sono riusciti. Controlla i dettagli sotto.",
      ok ? "success" : "error"
    );
    renderTestResults(data.results);
  } catch (err) {
    setStatus(testsStatus, err.message, "error");
  } finally {
    testsBtn.disabled = false;
  }
});
