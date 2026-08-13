const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..", "..");
const globalRoot = execFileSync("npm", ["root", "--global"], { encoding: "utf8", shell: true }).trim();
const esbuild = require(path.join(globalRoot, "esbuild"));
const entryPath = path.join(__dirname, "ssa-demo-presenter.jsx");
const cssPath = path.join(__dirname, "ssa-demo-presenter.css");
const outputPath = path.join(
  repoRoot,
  "specs",
  "ssa-earnings-integrity-case-review-v2",
  "ssa-earnings-integrity-demo-presenter.html",
);

const result = esbuild.buildSync({
  entryPoints: [entryPath],
  bundle: true,
  write: false,
  format: "iife",
  platform: "browser",
  target: ["chrome110", "edge110"],
  jsx: "automatic",
  minify: true,
  legalComments: "none",
  nodePaths: [globalRoot],
});

const script = result.outputFiles[0].text.replace(/<\/script/gi, "<\\/script");
const css = fs.readFileSync(cssPath, "utf8");
const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>SSA Earnings Integrity - 40-Minute Demo Companion</title>
  <script>
    (() => {
      const param = new URLSearchParams(window.location.search).get("clawpilotTheme");
      const theme =
        param || (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
      document.documentElement.setAttribute("data-theme", theme);
    })();
  </script>
  <style>${css}</style>
</head>
<body>
  <div id="root"></div>
  <script>${script}</script>
</body>
</html>
`;

fs.writeFileSync(outputPath, html, "utf8");
console.log(`Created ${outputPath}`);