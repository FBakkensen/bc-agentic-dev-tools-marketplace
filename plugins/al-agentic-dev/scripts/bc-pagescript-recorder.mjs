#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import readline from "node:readline";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";

const DEFAULT_COMPANY = "CRONUS International Ltd.";
const DEFAULT_SERVER_INSTANCE = "BC";
const COMMANDS = ["screenshot", "click", "key", "type", "wait", "stopSave", "readYml", "close"];

function emit(payload) {
  process.stdout.write(`${JSON.stringify(payload)}\n`);
}

function fail(message, details = {}) {
  const error = new Error(message);
  error.details = details;
  return error;
}

function parseArgs(argv) {
  const args = {};

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      throw fail(`Unexpected argument '${arg}'.`);
    }

    const key = arg.slice(2);
    if (key === "headed") {
      args.headed = true;
      continue;
    }
    if (key === "headless") {
      args.headed = false;
      continue;
    }

    const value = argv[i + 1];
    if (!value || value.startsWith("--")) {
      throw fail(`Missing value for --${key}.`);
    }
    i += 1;

    switch (key) {
      case "repo-root":
        args.repoRoot = value;
        break;
      case "run-dir":
        args.runDir = value;
        break;
      case "output":
      case "output-yml":
        args.output = value;
        break;
      case "container":
        args.container = value;
        break;
      case "company":
        args.company = value;
        break;
      case "page":
        args.page = value;
        break;
      case "server-instance":
        args.serverInstance = value;
        break;
      case "url":
        args.url = value;
        break;
      case "timeout-ms":
        args.timeoutMs = Number(value);
        break;
      default:
        throw fail(`Unknown option --${key}.`);
    }
  }

  return args;
}

function sanitizeBranch(branch) {
  const value = branch.replace(/[\\/]/g, "-").replace(/[^\w-]/g, "");
  if (!value) {
    throw fail(`Could not derive container name from branch '${branch}'.`);
  }
  return value;
}

function currentBranchContainerName(repoRoot) {
  const branch = execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
    cwd: repoRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  }).trim();

  if (!branch) {
    throw fail("Could not detect git branch name. Use --container or BC_CONTAINER.");
  }

  return sanitizeBranch(branch);
}

function resolveInsideRepo(repoRoot, candidate) {
  if (!candidate) {
    return null;
  }
  return path.resolve(path.isAbsolute(candidate) ? candidate : path.join(repoRoot, candidate));
}

async function exists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function readJson(filePath) {
  try {
    return JSON.parse(await fs.readFile(filePath, "utf8"));
  } catch (error) {
    throw fail(`Failed to read JSON from ${filePath}: ${error.message}`);
  }
}

function requirePlaywright(repoRoot) {
  const pagescriptsPackageJson = path.join(repoRoot, "pagescripts", "package.json");
  const requireFromPagescripts = createRequire(pagescriptsPackageJson);

  try {
    return requireFromPagescripts("playwright");
  } catch (playwrightError) {
    try {
      return requireFromPagescripts("@playwright/test");
    } catch {
      throw fail(
        "Playwright is not resolvable from pagescripts/package.json. Run the page-script replay setup so pagescripts/node_modules contains @microsoft/bc-replay and its Playwright dependency.",
        { cause: playwrightError.message },
      );
    }
  }
}

function buildStartUrl({ containerName, serverInstance, company, page, explicitUrl }) {
  if (explicitUrl) {
    return explicitUrl;
  }

  const url = new URL(`http://${containerName}/${serverInstance}/`);
  if (company) {
    url.searchParams.set("company", company);
  }
  if (page) {
    url.searchParams.set("page", page);
  }
  url.searchParams.set("dc", "0");
  return url.toString();
}

async function screenshot(page, dir, name = "screenshot") {
  await fs.mkdir(dir, { recursive: true });
  const safeName = name.replace(/[^\w.-]+/g, "-").replace(/^-+|-+$/g, "") || "screenshot";
  const filePath = path.join(dir, `${new Date().toISOString().replace(/[:.]/g, "-")}-${safeName}.png`);
  await page.screenshot({ path: filePath, fullPage: false });
  emit({ event: "screenshot", path: filePath });
  return filePath;
}

async function firstVisible(locator, label) {
  const count = await locator.count();
  for (let i = 0; i < count; i += 1) {
    const candidate = locator.nth(i);
    if (await candidate.isVisible().catch(() => false)) {
      return candidate;
    }
  }
  throw fail(`No visible element found for ${label}.`);
}

async function findVisibleAcrossFrames(page, makeLocator, label, options = {}) {
  const timeout = options.timeout ?? 30000;
  const reverse = options.reverse ?? false;
  const deadline = Date.now() + timeout;

  while (Date.now() < deadline) {
    for (const frame of page.frames()) {
      let locator;
      let count;
      try {
        locator = makeLocator(frame);
        count = await locator.count();
      } catch {
        continue;
      }

      const indexes = Array.from({ length: count }, (_, index) => index);
      if (reverse) {
        indexes.reverse();
      }

      for (const index of indexes) {
        const candidate = locator.nth(index);
        if (await candidate.isVisible().catch(() => false)) {
          return candidate;
        }
      }
    }

    await page.waitForTimeout(250);
  }

  throw fail(`No visible element found across frames for ${label}.`);
}

async function clickVisibleAcrossFrames(page, makeLocator, label, options = {}) {
  const locator = await findVisibleAcrossFrames(page, makeLocator, label, options);
  await locator.click(options.clickOptions ?? {});
  return locator;
}

async function maybeLogin(page, username, password, timeoutMs) {
  await page.waitForLoadState("domcontentloaded", { timeout: timeoutMs }).catch(() => {});

  const passwordInput = page.locator('input[type="password"]');
  if ((await passwordInput.count()) === 0) {
    return false;
  }

  emit({ event: "login", state: "password-form-detected" });
  const userInput = page.locator(
    'input[type="text"], input[type="email"], input[name*="user" i], input[id*="user" i]',
  );

  await (await firstVisible(userInput, "username input")).click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.type(username);

  await (await firstVisible(passwordInput, "password input")).click();
  await page.keyboard.press(process.platform === "darwin" ? "Meta+A" : "Control+A");
  await page.keyboard.type(password);

  const signInButton = page.getByRole("button", { name: /sign in|log in/i });
  if ((await signInButton.count()) > 0) {
    await (await firstVisible(signInButton, "sign-in button")).click();
  } else {
    await page.keyboard.press("Enter");
  }

  await page.waitForLoadState("networkidle", { timeout: timeoutMs }).catch(() => {});
  return true;
}

async function waitForBcShell(page, timeoutMs) {
  await page.getByRole("button", { name: /settings/i }).waitFor({ timeout: timeoutMs });
}

async function openPageScripting(page) {
  await page.getByRole("button", { name: /settings/i }).click();
  await clickVisibleAcrossFrames(
    page,
    (frame) => frame.getByText(/Page scripting \(Preview\)/i),
    "Page scripting (Preview)",
  );
  await findVisibleAcrossFrames(
    page,
    (frame) => frame.getByText("Start new", { exact: true }),
    "Start new recorder button",
    { timeout: 5000 },
  ).catch(async () => {
    await findVisibleAcrossFrames(
      page,
      (frame) => frame.locator('button[title="Start recording"], button[aria-label="Start recording"]'),
      "Start recording button",
    );
  });
}

async function startRecording(page) {
  await clickVisibleAcrossFrames(
    page,
    (frame) => frame.getByText("Start new", { exact: true }),
    "Start new recorder button",
    { timeout: 5000 },
  ).catch(async () => {
    await clickVisibleAcrossFrames(
      page,
      (frame) => frame.locator('button[title="Start recording"], button[aria-label="Start recording"]'),
      "Start recording button",
    );
  });

  await page.waitForTimeout(500);
  emit({ event: "recording", state: "started" });
}

async function clickOptionalFinalSave(page) {
  const finalButton = await findVisibleAcrossFrames(
    page,
    (frame) => frame.getByRole("button", { name: /^(Save|Yes|OK)$/i }),
    "final save confirmation button",
    { timeout: 5000, reverse: true },
  ).catch(() => null);

  if (finalButton) {
    await finalButton.click();
    emit({ event: "save", state: "confirmed" });
  }
}

async function stopAndDownload(page, outputYmlPath) {
  await clickVisibleAcrossFrames(
    page,
    (frame) => frame.locator('button[title="Stop"], button[aria-label="Stop"]'),
    "Stop recording button",
  );
  await page.waitForTimeout(500);
  emit({ event: "recording", state: "stopped" });

  await clickVisibleAcrossFrames(
    page,
    (frame) => frame.locator('button[aria-label="More commands"], button[title="More commands"]'),
    "recorder more commands",
    { reverse: true },
  );

  await fs.mkdir(path.dirname(outputYmlPath), { recursive: true });
  if (await exists(outputYmlPath)) {
    await fs.unlink(outputYmlPath);
  }

  const downloadPromise = page.waitForEvent("download", { timeout: 60000 });
  await clickVisibleAcrossFrames(
    page,
    (frame) => frame.getByText("Save recording as...", { exact: true }),
    "Save recording as command",
  );
  await clickOptionalFinalSave(page);

  const download = await downloadPromise;
  await download.saveAs(outputYmlPath);
  emit({
    event: "download",
    path: outputYmlPath,
    suggestedFilename: download.suggestedFilename(),
  });
}

async function readYml(outputYmlPath) {
  const yml = await fs.readFile(outputYmlPath, "utf8");
  const preview = yml.split(/\r?\n/).slice(0, 80).join("\n");
  emit({
    event: "yml",
    path: outputYmlPath,
    bytes: Buffer.byteLength(yml),
    preview,
  });
}

function locatorFor(frame, command) {
  if (command.selector) {
    return frame.locator(command.selector);
  }
  if (command.role) {
    const roleOptions = {};
    if (command.nameRegex) {
      roleOptions.name = new RegExp(command.nameRegex, command.regexFlags || "i");
    } else if (command.name) {
      roleOptions.name = command.name;
    }
    return frame.getByRole(command.role, roleOptions);
  }
  if (command.label) {
    return frame.getByLabel(command.label, { exact: command.exact ?? true });
  }
  if (command.title) {
    return frame.getByTitle(command.title, { exact: command.exact ?? true });
  }
  if (command.text) {
    return frame.getByText(command.text, { exact: command.exact ?? true });
  }
  throw fail(`Command '${command.cmd}' needs x/y, selector, role/name, label, title, or text.`);
}

async function resolveCommandLocator(page, command, label) {
  return findVisibleAcrossFrames(page, (frame) => locatorFor(frame, command), label, {
    timeout: command.timeoutMs ?? 30000,
    reverse: Boolean(command.reverse),
  });
}

function normalizeCommand(line) {
  const trimmed = line.trim();
  if (!trimmed) {
    return null;
  }

  if (trimmed.startsWith("{")) {
    const command = JSON.parse(trimmed);
    if (!command.cmd && command.command) {
      command.cmd = command.command;
    }
    return command;
  }

  const [cmd, ...rest] = trimmed.split(/\s+/);
  const arg = rest.join(" ");
  if (cmd === "wait") {
    return { cmd, ms: arg ? Number(arg) : 1000 };
  }
  if (cmd === "type") {
    return { cmd, text: arg };
  }
  if (cmd === "key") {
    return { cmd, key: arg };
  }
  if (cmd === "click") {
    return arg ? { cmd, text: arg, exact: false } : { cmd };
  }
  if (cmd === "screenshot") {
    return { cmd, name: arg || "agent" };
  }
  return { cmd };
}

async function handleCommand(command, page, context, browser, runDir, screenshotsDir, outputYmlPath) {
  switch (command.cmd) {
    case "screenshot": {
      const filePath = await screenshot(page, screenshotsDir, command.name || "agent");
      emit({ ok: true, cmd: command.cmd, path: filePath });
      return true;
    }
    case "click": {
      if (Number.isFinite(command.x) && Number.isFinite(command.y)) {
        await page.mouse.click(command.x, command.y, {
          button: command.button || "left",
          clickCount: command.clickCount || 1,
        });
      } else {
        const locator = await resolveCommandLocator(page, command, "click target");
        await locator.click(command.clickOptions ?? {});
      }
      emit({ ok: true, cmd: command.cmd });
      return true;
    }
    case "key": {
      if (!command.key) {
        throw fail("key command requires key.");
      }
      await page.keyboard.press(command.key);
      emit({ ok: true, cmd: command.cmd });
      return true;
    }
    case "type": {
      const text = command.value ?? command.text ?? "";
      if (command.selector || command.role || command.label || command.title) {
        const locator = await resolveCommandLocator(page, command, "type target");
        await locator.click();
      }
      await page.keyboard.type(text);
      emit({ ok: true, cmd: command.cmd });
      return true;
    }
    case "wait": {
      if (command.selector || command.role || command.label || command.title || command.text) {
        await resolveCommandLocator(page, command, "wait target");
      } else {
        await page.waitForTimeout(command.ms || 1000);
      }
      emit({ ok: true, cmd: command.cmd });
      return true;
    }
    case "stopSave": {
      await stopAndDownload(page, outputYmlPath);
      await screenshot(page, screenshotsDir, "after-download").catch(() => null);
      await readYml(outputYmlPath);
      emit({ ok: true, cmd: command.cmd });
      return true;
    }
    case "readYml": {
      await readYml(outputYmlPath);
      emit({ ok: true, cmd: command.cmd });
      return true;
    }
    case "close": {
      await context.close().catch(() => {});
      await browser.close().catch(() => {});
      emit({ ok: true, cmd: command.cmd, runDir });
      return false;
    }
    default:
      throw fail(`Unknown command '${command.cmd}'. Supported commands: ${COMMANDS.join(", ")}.`);
  }
}

async function commandLoop(page, context, browser, runDir, screenshotsDir, outputYmlPath) {
  const rl = readline.createInterface({ input: process.stdin, terminal: false, crlfDelay: Infinity });

  for await (const line of rl) {
    const command = normalizeCommand(line);
    if (!command) {
      continue;
    }

    try {
      const keepGoing = await handleCommand(command, page, context, browser, runDir, screenshotsDir, outputYmlPath);
      if (!keepGoing) {
        return;
      }
    } catch (error) {
      await screenshot(page, screenshotsDir, `error-${command.cmd || "command"}`).catch(() => null);
      emit({
        ok: false,
        cmd: command.cmd,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  emit({ event: "stdin", state: "closed", runDir });
  await context.close().catch(() => {});
  await browser.close().catch(() => {});
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const repoRoot = path.resolve(args.repoRoot ?? process.cwd());
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const runDir = resolveInsideRepo(
    repoRoot,
    args.runDir ?? process.env.BC_RECORDER_RUN_DIR ?? path.join(".tmp", "bc-pagescript-recorder", timestamp),
  );
  const screenshotsDir = path.join(runDir, "screenshots");
  const errorLogPath = path.join(runDir, "error.log");
  const outputYmlPath = resolveInsideRepo(
    repoRoot,
    args.output ?? process.env.BC_RECORDER_OUTPUT ?? path.join(runDir, "Recording.yml"),
  );

  await fs.mkdir(screenshotsDir, { recursive: true });

  let browser;
  let context;
  let page;

  try {
    const configPath = path.join(repoRoot, "al-build.json");
    if (!(await exists(configPath))) {
      throw fail(`al-build.json not found at ${configPath}.`);
    }

    const pagescriptsPackageJson = path.join(repoRoot, "pagescripts", "package.json");
    if (!(await exists(pagescriptsPackageJson))) {
      throw fail(`pagescripts/package.json not found at ${pagescriptsPackageJson}. Run the page-script replay setup first.`);
    }

    const config = await readJson(configPath);
    const containerName = args.container ?? process.env.BC_CONTAINER ?? currentBranchContainerName(repoRoot);
    const serverInstance = args.serverInstance ?? process.env.BC_SERVER_INSTANCE ?? config.serverInstance ?? DEFAULT_SERVER_INSTANCE;
    const company = args.company ?? process.env.BC_COMPANY ?? DEFAULT_COMPANY;
    const pageId = args.page ?? process.env.BC_PAGE ?? null;
    const timeoutMs = args.timeoutMs || Number(process.env.BC_RECORDER_TIMEOUT_MS || 90000);
    const headed = args.headed ?? process.env.BC_RECORDER_HEADED === "1";
    const startUrl = buildStartUrl({
      containerName,
      serverInstance,
      company,
      page: pageId,
      explicitUrl: args.url ?? process.env.BC_URL,
    });

    const containerConfig = config.container ?? {};
    const username = process.env.BC_USERNAME ?? containerConfig.username;
    const password = process.env.BC_PASSWORD ?? containerConfig.password;
    if (!username || !password) {
      throw fail("BC username/password not found. Set BC_USERNAME/BC_PASSWORD or container.username/container.password in al-build.json.");
    }

    const { chromium } = requirePlaywright(repoRoot);

    emit({ event: "start", url: startUrl, runDir });
    browser = await chromium.launch({ headless: !headed });
    context = await browser.newContext({
      acceptDownloads: true,
      httpCredentials: { username, password },
      viewport: { width: 1600, height: 1000 },
    });
    page = await context.newPage();

    await page.goto(startUrl, { waitUntil: "domcontentloaded", timeout: timeoutMs });
    await maybeLogin(page, username, password, timeoutMs);
    await waitForBcShell(page, timeoutMs);
    await screenshot(page, screenshotsDir, "01-bc-shell");

    await openPageScripting(page);
    await screenshot(page, screenshotsDir, "02-page-scripting-open");

    await startRecording(page);
    await screenshot(page, screenshotsDir, "03-recording-started");

    emit({
      event: "READY_FOR_AGENT_FLOW",
      commands: COMMANDS,
      protocol: "Send either JSON lines like {\"cmd\":\"click\",\"text\":\"Open\"} or plain commands like screenshot, key Enter, wait 1000, stopSave, readYml, close.",
    });

    await commandLoop(page, context, browser, runDir, screenshotsDir, outputYmlPath);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await fs.writeFile(errorLogPath, error instanceof Error && error.stack ? error.stack : message, "utf8").catch(() => {});
    const screenshotPath = page ? await screenshot(page, screenshotsDir, "error").catch(() => null) : null;
    emit({ event: "error", message, runDir, errorLog: errorLogPath, screenshot: screenshotPath });
    await context?.close().catch(() => {});
    await browser?.close().catch(() => {});
    process.exitCode = 1;
  }
}

main();
