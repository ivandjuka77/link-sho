// In dev, Vite proxies /api to the backend. In prod, nginx proxies /api.
const API = "/api";

const form = document.getElementById("form");
const input = document.getElementById("url");
const result = document.getElementById("result");
const tbody = document.querySelector("#links tbody");

async function loadLinks() {
  const res = await fetch(`${API}/links`);
  const links = await res.json();
  tbody.innerHTML = links
    .map((l) => `<tr><td>${l.code}</td><td>${l.url}</td><td>${l.hits}</td></tr>`)
    .join("");
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const res = await fetch(`${API}/shorten`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url: input.value }),
  });
  const data = await res.json();
  result.textContent = `${location.origin}/${data.code}`;
  input.value = "";
  loadLinks();
});

loadLinks();
