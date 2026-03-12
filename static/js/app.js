const dropzone   = document.getElementById("dropzone");
const fileInput  = document.getElementById("fileInput");
const dropContent  = document.getElementById("dropContent");
const filePreview  = document.getElementById("filePreview");
const fileNameEl   = document.getElementById("fileName");
const fileSizeEl   = document.getElementById("fileSize");
const removeBtn    = document.getElementById("removeFile");
const convertBtn   = document.getElementById("convertBtn");
const btnText      = convertBtn.querySelector(".btn-text");
const btnSpinner   = convertBtn.querySelector(".btn-spinner");
const errorAlert   = document.getElementById("errorAlert");
const errorMsg     = document.getElementById("errorMsg");
const successAlert = document.getElementById("successAlert");

let selectedFile = null;

function formatBytes(bytes) {
  if (bytes < 1024) return bytes + " B";
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
  return (bytes / (1024 * 1024)).toFixed(1) + " MB";
}

function setFile(file) {
  if (!file) return;

  const ext = file.name.split(".").pop().toLowerCase();
  if (!["doc", "docx"].includes(ext)) {
    showError("Only .doc and .docx files are supported.");
    return;
  }

  if (file.size > 50 * 1024 * 1024) {
    showError("File exceeds the 50 MB size limit.");
    return;
  }

  selectedFile = file;
  fileNameEl.textContent = file.name;
  fileSizeEl.textContent = formatBytes(file.size);
  dropContent.hidden = true;
  filePreview.hidden = false;
  convertBtn.disabled = false;
  hideAlerts();
}

function clearFile() {
  selectedFile = null;
  fileInput.value = "";
  dropContent.hidden = false;
  filePreview.hidden = true;
  convertBtn.disabled = true;
  hideAlerts();
}

function showError(msg) {
  errorMsg.textContent = msg;
  errorAlert.hidden = false;
  successAlert.hidden = true;
}

function showSuccess() {
  successAlert.hidden = false;
  errorAlert.hidden = true;
}

function hideAlerts() {
  errorAlert.hidden = true;
  successAlert.hidden = true;
}

function setConverting(active) {
  convertBtn.disabled = active;
  btnText.hidden = active;
  btnSpinner.hidden = !active;
}

// Dropzone click → open file dialog
dropzone.addEventListener("click", (e) => {
  if (e.target === removeBtn || removeBtn.contains(e.target)) return;
  fileInput.click();
});

fileInput.addEventListener("change", () => {
  if (fileInput.files[0]) setFile(fileInput.files[0]);
});

removeBtn.addEventListener("click", (e) => {
  e.stopPropagation();
  clearFile();
});

// Drag and drop
dropzone.addEventListener("dragover", (e) => {
  e.preventDefault();
  dropzone.classList.add("drag-over");
});

dropzone.addEventListener("dragleave", () => {
  dropzone.classList.remove("drag-over");
});

dropzone.addEventListener("drop", (e) => {
  e.preventDefault();
  dropzone.classList.remove("drag-over");
  const file = e.dataTransfer.files[0];
  if (file) setFile(file);
});

// Convert
convertBtn.addEventListener("click", async () => {
  if (!selectedFile) return;

  hideAlerts();
  setConverting(true);

  const formData = new FormData();
  formData.append("file", selectedFile);

  try {
    const response = await fetch("/convert", {
      method: "POST",
      body: formData,
    });

    if (!response.ok) {
      const data = await response.json().catch(() => ({}));
      showError(data.error || `Server error: ${response.status}`);
      return;
    }

    // Trigger download from the blob
    const blob = await response.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    const disposition = response.headers.get("Content-Disposition") || "";
    const match = disposition.match(/filename="?([^"]+)"?/);
    a.download = match ? match[1] : selectedFile.name.replace(/\.docx?$/i, ".pdf");
    a.href = url;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);

    showSuccess();
    clearFile();
  } catch (err) {
    showError("Network error — please check your connection and try again.");
  } finally {
    setConverting(false);
  }
});
