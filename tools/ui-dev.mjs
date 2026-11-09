// tools/ui-dev.mjs - Lokální vývojový server pro náhled Web UI v prohlížeči (http://localhost:5180)
import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { join, dirname, extname } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const uiDir = join(root, "ui");
const port = 5180;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".svg": "image/svg+xml",
};

const server = createServer((req, res) => {
  let url = req.url.split("?")[0];
  if (url === "/" || url === "") url = "/index.html";

  const filePath = join(uiDir, url);
  if (!existsSync(filePath)) {
    res.statusCode = 404;
    res.end("Not found");
    return;
  }

  const ext = extname(filePath).toLowerCase();
  res.setHeader("Content-Type", MIME[ext] || "text/plain");

  let content = readFileSync(filePath);

  // Injektovat dev mock bridge do index.html
  if (url === "/index.html") {
    const devBridge = `
<script>
window.__animaceDev = function(name, payload) {
  console.log("[DEV BRIDGE] Client -> Server:", name, payload);
  if (payload && payload.op === "zavrit") {
    alert("Zavření okna náhledu.");
  }
};
</script>
`;
    content = Buffer.from(content.toString("utf8").replace("</head>", `${devBridge}</head>`), "utf8");
  }

  res.end(content);
});

server.listen(port, () => {
  console.log(`UI Dev server bezi na http://localhost:${port}/`);
});
