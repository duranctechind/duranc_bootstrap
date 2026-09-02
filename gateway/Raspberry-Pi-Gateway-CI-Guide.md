# Raspberry Pi Gateway Installers — CI Build Guide

How the Duranc VMS gateway installers for Raspberry Pi are built, rebuilt, and shipped.

- **Repo:** `duranctechind/duranc_bootstrap` (public)
- **CI workflow:** `.github/workflows/build-rasp-pi-installers.yml`
- **Sources you edit:** `gateway/src/rasp-pi/`
- **Build output (do not edit by hand):** `gateway/*.sh.x`

> One installer serves **both Raspberry Pi 4 and Pi 5** — they are both aarch64 and run the
> same `durancai/*-gateway-rasp-pi` (`linux/arm64`) image. There is no separate Pi 5 build.

---

## 1. What CI does (and does not) build

| File type | Location | Built by CI? |
|---|---|---|
| Installer sources (`.sh`) | `gateway/src/rasp-pi/` | You **edit** these |
| Compiled installers (`.sh.x`) | `gateway/` | **Yes** — CI compiles and commits them |
| Compose files (`doc-comp-gw-rasp-pi*.yml`) | `gateway/` | **No** — plain YAML, devices pull them directly |

**Compose files never need CI.** Edit the `.yml` in the repo and it is live for the next
install immediately. CI is only for turning the `.sh` sources into obfuscated `.sh.x`
binaries.

The sources and their outputs:

| Source (`gateway/src/rasp-pi/`) | Compiles to (`gateway/`) |
|---|---|
| `duranc_gw_rasp_pi.sh` | `duranc_gw_rasp_pi.sh.x`, `duranc_gw_rasp_pi_prod.sh.x`, `duranc_gw_rasp_pi_nas.sh.x` |
| `delayedstart_rasp_pi.sh` | `delayedstart_rasp_pi.sh.x` |
| `doc_container_status_rasp_pi.sh` | `doc_container_status_rasp_pi.sh.x` |

The three `duranc_gw_*` outputs come from **one** source; they differ only in the baked-in
default mode (`staging` / `prod` / `nas`), which is also overridable at run time.

---

## 2. The normal workflow — edit a script and rebuild

Prerequisite: `git` and the GitHub CLI (`gh`) installed and authenticated
(`gh auth status`).

```bash
# 1. Clone (first time) or pull
git clone https://github.com/duranctechind/duranc_bootstrap
cd duranc_bootstrap
# (subsequent times)  git pull

# 2. Edit a source — NEVER the .sh.x files
nano gateway/src/rasp-pi/duranc_gw_rasp_pi.sh

# 3. Commit and push
git add gateway/src/rasp-pi/duranc_gw_rasp_pi.sh
git commit -m "installer: <what you changed>"
git push
```

**The push auto-triggers the build** — the workflow watches for any change under
`gateway/src/rasp-pi/**`. Nothing else in the repo triggers it.

```bash
# 4. Watch the build to completion (exits non-zero if it fails)
gh run watch \
  "$(gh run list -R duranctechind/duranc_bootstrap -w build-rasp-pi-installers.yml -L1 --json databaseId --jq '.[0].databaseId')" \
  --exit-status
```

When it finishes, CI has committed the rebuilt `gateway/*.sh.x` back to `master` with a
`[skip ci]` message (so it does not re-trigger itself). Run `git pull` to get them locally.

---

## 3. Trigger a build manually

Use this to rebuild without changing a source (e.g. after rotating the pull token):

```bash
gh workflow run build-rasp-pi-installers.yml -R duranctechind/duranc_bootstrap
```

Or on GitHub: **Actions → Build Raspberry Pi gateway installers → Run workflow → master**.

---

## 4. One-time setup (already done — for reference)

Two repository secrets hold the read-only Docker Hub pull credentials. CI injects them into
the installer at build time so the token is never stored in plaintext in this public repo.

```bash
printf 'durancinc' | gh secret set DOCKERHUB_PULL_USER  -R duranctechind/duranc_bootstrap
printf '<pull-token>' | gh secret set DOCKERHUB_PULL_TOKEN -R duranctechind/duranc_bootstrap
```

Confirm they exist:

```bash
gh secret list -R duranctechind/duranc_bootstrap
# expect: DOCKERHUB_PULL_USER, DOCKERHUB_PULL_TOKEN
```

If either is missing the build fails on purpose with
`secret DOCKERHUB_PULL_USER is not set` rather than shipping an installer with a blank
token.

> **Rule:** the sources keep the placeholders `__DOCKER_HUB_USER__` and
> `__DOCKER_HUB_TOKEN__`. Never paste a real token into a source file — CI fills them in.

---

## 5. How the build works under the hood

Understanding this explains the two things that make it CI-only rather than a local build.

1. **`shc` produces a native binary**, so an aarch64 `.sh.x` must be compiled on aarch64.
   The workflow runs on a GitHub-hosted `ubuntu-24.04-arm` runner (native aarch64, no QEMU).

2. **The runner is glibc 2.39**, and an `shc` binary links against the glibc it was built
   on. A binary built directly on the runner would fail on Raspberry Pi OS bookworm with
   `GLIBC_2.38 not found`. So the compile runs inside a **`debian:bullseye` container**
   (glibc 2.31), whose binaries run on Pi OS bullseye, bookworm and trixie alike.

Each build step, in order:
- injects the token secrets into the source,
- checks the placeholder is gone and `bash -n` passes,
- compiles with `shc`,
- asserts the binary is **aarch64** and needs **glibc ≤ 2.31**,
- runs the compiled installer with an invalid mode to prove the payload decodes and
  executes on this architecture,
- commits the five `.sh.x` back to `gateway/`.

---

## 6. Verify a build landed

```bash
# the .sh.x files were updated by the CI commit
gh api repos/duranctechind/duranc_bootstrap/commits -q '.[0].commit.message'
# expect: "ci: rebuild Raspberry Pi gateway installers with shc ... [skip ci]"
```

On a Pi, the installers are pulled fresh each install, so the next customer setup picks up
the new build automatically.

---

## 7. Changing a compose file (no CI)

The compose files are plain YAML that devices `curl` at install time, so a change is live
for the **next** install as soon as it is pushed — there is no build.

```bash
cd duranc_bootstrap && git pull
nano gateway/doc-comp-gw-rasp-pi.yml        # or -prod.yml / -nas.yml
git add gateway/doc-comp-gw-rasp-pi.yml
git commit -m "compose: <what changed>"
git push
```

- A change affects **new installs only**. An already-installed Pi has its own copy at
  `~/.dur-gw-rasp-pi.yml`; to update it, edit that file and run
  `sudo docker compose -f ~/.dur-gw-rasp-pi.yml up -d`.
- Leave the `__NODE_HEAP__` placeholder in the repo file — the installer substitutes the
  real value per board (2048, or 1024 on a 2 GB Pi 4).

---

## 8. Local build fallback (only if GitHub is unavailable)

The exact same compile can run on any **aarch64** box (e.g. a Pi). You must supply the
token yourself, which is why CI is preferred.

```bash
sudo apt-get update && sudo apt-get install -y shc gcc
sed -e 's/__DOCKER_HUB_USER__/durancinc/g' \
    -e 's/__DOCKER_HUB_TOKEN__/<pull-token>/g' \
    gateway/src/rasp-pi/duranc_gw_rasp_pi.sh > /tmp/w.sh
shc -r -f /tmp/w.sh -o duranc_gw_rasp_pi.sh.x
file duranc_gw_rasp_pi.sh.x        # must say: ELF 64-bit ... ARM aarch64
```

Do **not** run `shc` on the x86 installation-scripts box (18.18.18.130) — it would emit an
x86 binary that cannot run on a Pi at all.

---

## 9. Troubleshooting the build

| Symptom | Cause / fix |
|---|---|
| `secret DOCKERHUB_PULL_USER is not set` | Set the two repo secrets (section 4). |
| `token placeholder survived injection` | A source lost its `__DOCKER_HUB_*__` placeholder — restore it. |
| `.sh.x is not an aarch64 binary` | The job did not run in the bullseye/arm container — check the workflow was not edited. |
| `needs glibc X, above the 2.31 floor` | The container base drifted off bullseye — keep it `debian:bullseye`. |
| `no C compiler in the build container` | `gcc` missing; the workflow installs `shc gcc` — do not remove `gcc`. |
| Build did not trigger on push | You changed a file **outside** `gateway/src/rasp-pi/` — trigger manually (section 3). |

---

## Appendix — the install commands devices run

For reference; these pull the compiled installers this CI produces.

```bash
# Staging
curl -fsSL https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway/duranc_gw_rasp_pi.sh.x -o $HOME/.dgw.sh.x && chmod +x $HOME/.dgw.sh.x && $HOME/.dgw.sh.x

# Production
curl -fsSL https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway/duranc_gw_rasp_pi_prod.sh.x -o $HOME/.dgw.sh.x && chmod +x $HOME/.dgw.sh.x && $HOME/.dgw.sh.x

# Production + NAS  (link the NAS to /local-storage first)
curl -fsSL https://raw.githubusercontent.com/duranctechind/duranc_bootstrap/master/gateway/duranc_gw_rasp_pi_nas.sh.x -o $HOME/.dgw.sh.x && chmod +x $HOME/.dgw.sh.x && $HOME/.dgw.sh.x
```
