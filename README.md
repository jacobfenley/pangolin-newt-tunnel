# Pangolin Newt Tunnel Setup

This package sets up the Pangolin Newt tunnel agent as a persistent service on a Linux host. Once installed, the tunnel starts automatically on boot and reconnects if it drops. A smoke test is included to verify end-to-end routing before deploying real services.

---

## Prerequisites

- A Pangolin account (cloud at [app.pangolin.net](https://app.pangolin.net) or self-hosted)
- A site created in Pangolin with the Site ID and Secret copied from the Credentials tab
- A Linux server (Debian or Ubuntu recommended — Hetzner VPS works perfectly)
- Root or sudo access

**Where to find your Site ID and Secret:** In the Pangolin dashboard, go to Sites → your site → Credentials tab. You will see the Endpoint, ID, and Secret. Copy all three before running setup.

---

## Quick Start — Fresh Server (Recommended)

```bash
git clone <repo-url>
cd <repo-directory>
chmod +x install.sh setup.sh update.sh
sudo ./install.sh
```

`install.sh` installs Docker if needed, configures it to start on boot, runs the credential wizard, and starts the tunnel. After it completes, the tunnel is live and will survive reboots automatically.

---

## Quick Start — Docker Already Installed

```bash
chmod +x setup.sh update.sh
./setup.sh
sudo systemctl enable docker
docker compose up -d
```

---

## Credential Modes

Three ways to provide credentials, in order of recommended use:

**Wizard (default):** Run `setup.sh`. Writes `newt.env` and `newt-config.secret`. The compose file reads `newt.env` automatically. Best for interactive setup by a human.

**Environment variables:** For CI pipelines or scripted deployments. Set `PANGOLIN_ENDPOINT`, `NEWT_ID`, and `NEWT_SECRET` in the environment, uncomment the env var block in `docker-compose.yml`, and remove the `env_file` line. No files written to disk.

**Compose secrets:** Most secure for production. Uses `newt-config.secret` mounted as a Docker secret via `CONFIG_FILE`. Separates credentials from compose configuration entirely. Uncomment the secrets block in `docker-compose.yml`.

---

## How Boot Persistence Works

- `systemctl enable docker` tells systemd to start Docker when the server boots
- `live-restore: true` in `/etc/docker/daemon.json` keeps containers running during Docker daemon upgrades
- `restart: unless-stopped` tells Docker to restart the Newt container automatically if it crashes or if Docker restarts
- The only thing that stops Newt from restarting is an intentional `docker compose down` or `docker stop newt`

```
Server boots
  → systemd starts Docker
    → Docker starts with live-restore enabled
      → newt container restarts automatically
        → Newt authenticates with Pangolin
          → Tunnel is live
```

`docker compose down` is a deliberate teardown that `unless-stopped` respects and will not override. Use `docker compose restart` or `docker compose up -d` to bounce the service without losing auto-start state.

---

## Testing Your Tunnel

### Step 1 — Start the test server

```bash
docker compose --profile test up -d
```

This starts a minimal web server on port 17480. It serves a single page confirming the tunnel is routing correctly. It does not restart automatically and will not interfere with production services.

### Step 2 — Create a Pangolin resource

Log into your Pangolin dashboard and navigate to your organization. Go to Resources → Add Resource. Fill in:

- **Name:** anything descriptive, e.g. `tunnel-test`
- **Subdomain:** something you will remember, e.g. `test`
- **Domain:** select your configured domain from the dropdown

Once created, open the resource and go to the **Proxy** tab. Configure the target:

- **Site:** select your site
- **Protocol:** `http`
- **Host:** `localhost`
- **Port:** `17480`

Save the target. Wait approximately 30 seconds for DNS and TLS to provision.

### Step 3 — Verify

Open the resource URL in a browser (shown in the Pangolin resource list). You should see a dark page with a green card reading **✓ Tunnel is working** along with your node label and port 17480.

If you see this page, your Newt tunnel is correctly installed, authenticated, and routing traffic through Pangolin to your host.

### Step 4 — Stop the test server

```bash
docker compose --profile test down
```

> **Warning:** Port 17480 is intentionally unusual — it is a test fixture only. Do not build anything on top of it. Always stop the test server when you are done verifying.

---

## Keeping Newt Updated

```bash
./update.sh
```

This pulls the latest `fosrl/newt:latest` image from Docker Hub and restarts the tunnel. Fossorial maintains this image — running `update.sh` always gets the current release. Credentials and configuration are not affected.

Run this periodically or whenever Pangolin releases a new version. Check [https://github.com/fosrl/newt/releases](https://github.com/fosrl/newt/releases) for release notes.

---

## Resetting Credentials

```bash
rm newt.env newt-config.secret
./setup.sh
docker compose up -d
```

---

## Troubleshooting

**Container exits immediately after starting**
Run `docker compose logs newt`. Almost always a credential problem — wrong Site ID, wrong Secret, or endpoint URL has a trailing slash or typo. Re-run `./setup.sh` to correct.

**Tunnel connects but resource URL shows an error**
Check that the Pangolin resource proxy target matches exactly: protocol `http`, host `localhost`, port matching your service. Common mistake is using `127.0.0.1` instead of `localhost` or having the wrong port.

**Smoke test page not loading**
Confirm the test server is running with `docker compose --profile test ps`. Confirm the Pangolin resource target is set to port `17480`. Check resource status in the Pangolin dashboard — the certificate may still be provisioning, wait 30–60 seconds and try again.

**`network_mode: host` not working**
This mode is required for Newt and confirmed in Pangolin's official documentation. It does not work on Docker Desktop for Mac or Windows — it is silently ignored, which causes the tunnel to misbehave. This package targets Linux hosts only. Use a Hetzner VPS or other Linux VM if developing on Mac or Windows.

**Tunnel disconnects and does not reconnect**
Check `docker compose ps` to confirm the container is still running. If it shows `Restarting`, there is a repeated crash — check logs. If it shows `Up`, the tunnel may have a temporary network interruption that Newt will recover from automatically within a few seconds.

**Docker not starting on boot after a server reboot**
Run `sudo systemctl enable docker` and reboot to confirm. Verify with `sudo systemctl is-enabled docker` — should return `enabled`. If `install.sh` was used, this should already be set.

**`docker compose down` stopped the tunnel and it did not restart**
This is correct behavior — `docker compose down` explicitly stops containers in a way that `unless-stopped` respects. Run `docker compose up -d` to bring it back. Use `docker compose restart` in the future to bounce without losing auto-start state.
