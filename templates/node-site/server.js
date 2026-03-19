/**
 * Минимальный пример. Замените на свой entrypoint (например dist/index.js после сборки).
 * Порт задаётся переменной PORT (в .env шаблона — APP_PORT).
 */
const http = require("http");

const port = Number(process.env.PORT) || 3000;

const server = http.createServer((req, res) => {
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.end("Node-шаблон работает. Замените server.js и зависимости в package.json.\n");
});

server.listen(port, "0.0.0.0", () => {
  console.log(`listening on 0.0.0.0:${port}`);
});
