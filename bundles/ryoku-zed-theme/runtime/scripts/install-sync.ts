import { copyFile, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { constants } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

const home = homedir();
const root = resolve(import.meta.dir, "..");
const systemd = join(home, ".config/systemd/user");
const serviceName = "ryoku-zed-theme-sync.service";
const pathName = "ryoku-zed-theme-sync.path";
const bun = process.execPath;
const initialSync = Bun.spawn([bun, "run", "theme:sync"], { cwd: root, stdout: "inherit", stderr: "inherit" });
const initialSyncCode = await initialSync.exited;
if (initialSyncCode !== 0) throw new Error(`Initial theme sync exited with ${initialSyncCode}; no watcher was installed.`);
await mkdir(systemd, { recursive: true });
const service = `[Unit]\nDescription=Sync the Ryoku palette into a Zed theme\n\n[Service]\nType=oneshot\nWorkingDirectory=${root}\nExecStart=${bun} run theme:sync\n`;
const path = `[Unit]\nDescription=Watch Ryoku's generated Zed Matugen theme\n\n[Path]\nPathChanged=${home}/.config/zed/themes/matugen.json\nUnit=${serviceName}\n\n[Install]\nWantedBy=default.target\n`;
const missing: Array<[string, string]> = [];
for (const [name, content] of [[serviceName, service], [pathName, path]] as const) {
  const destination = join(systemd, name);
  try {
    const current = await readFile(destination, "utf8");
    if (current !== content) throw new Error(`${destination} already exists with different content; move it aside before installing this watcher.`);
  } catch (error) {
    if (error instanceof Error && !("code" in error && error.code === "ENOENT")) throw error;
    missing.push([destination, content]);
  }
}
for (const [destination, content] of missing) await writeFile(destination, content, { flag: "wx" });

const reload = Bun.spawn(["systemctl", "--user", "daemon-reload"], { stdout: "inherit", stderr: "inherit" });
const reloadCode = await reload.exited;
if (reloadCode !== 0) throw new Error(`systemctl daemon-reload exited with ${reloadCode}`);
const proc = Bun.spawn(["systemctl", "--user", "enable", "--now", pathName], { stdout: "inherit", stderr: "inherit" });
const code = await proc.exited;
if (code !== 0) throw new Error(`systemctl exited with ${code}`);

const settings = join(home, ".config/zed/settings.json");
const currentSettings = await readFile(settings, "utf8");
const themeField = /^([\t ]*"theme"[\t ]*:[\t ]*)"(?:[^"\\]|\\.)*"([\t ]*,?)[\t ]*$/gm;
const matches = [...currentSettings.matchAll(themeField)];
if (matches.length !== 1) throw new Error(`Expected one string-valued theme setting in ${settings}; left it unchanged.`);
const selectedSettings = currentSettings.replace(themeField, `$1"Ryoku Dynamic Dark"$2`);
if (selectedSettings !== currentSettings) {
  const backup = `${settings}.ryoku-backup-${Date.now()}`;
  await copyFile(settings, backup, constants.COPYFILE_EXCL);
  const temp = `${settings}.ryoku-tmp-${Date.now()}`;
  await writeFile(temp, selectedSettings, { mode: 0o600, flag: "wx" });
  await rename(temp, settings);
  console.log(`Selected Ryoku Dynamic Dark in ${settings}; preserved the original as ${backup}.`);
} else {
  console.log(`Ryoku Dynamic Dark is already selected in ${settings}; left settings unchanged.`);
}
console.log("Installed the optional palette watcher. It writes ryoku-dynamic.json beside matugen.json and leaves Matugen untouched.");
