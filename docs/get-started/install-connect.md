# Install scry-connect on the robot

`scry-connect` is the Python MCP server that runs on your robot. It
exposes ROS 2 topics, nodes, services, actions, parameters, lifecycle,
diagnostics, and ~99 other tools to the AI agent on your phone.

Three install paths, in order of recommendation. All three install the
same `scry-connect` from PyPI — they just package it differently.

## Requirements

- **ROS 2** installed and sourced — Humble, Jazzy, Kilted, Lyrical, or
  Rolling. Any DDS (Fast-DDS, CycloneDDS, Connext, Zenoh) works since
  scry-connect uses `rclpy` (RMW-agnostic).
- **Python 3.10+** (ROS 2 ships its own python; that's fine).
- **WiFi** — the robot must be reachable from your phone on the LAN.
- **~50 MB disk** for the install. No GPU, no root, no special hardware.

## Option A — One-line installer (recommended)

Works on bare-metal Linux and inside Docker. The script auto-detects
your ROS distro, picks Docker if available else pip, writes a
`systemd --user` unit, starts the service, and prints a pairing QR.

```bash
curl -fsSL https://raw.githubusercontent.com/phaneron-robotics/scry-web/master/install.sh | bash
```

Re-running upgrades in place.

**Force a specific install mode:**

```bash
SCRY_INSTALL_MODE=docker bash    # always Docker
SCRY_INSTALL_MODE=pip bash       # always pip + systemd
```

When the script finishes you'll see a QR code in the terminal. Leave it
visible — you'll scan it from the phone in the next step.

## Option B — Docker sidecar (for compose-based deployments)

Drop into your existing `docker-compose.yml`:

```yaml
services:
  scry-connect:
    image: ghcr.io/phaneron-robotics/scry-connect:${ROS_DISTRO:-jazzy}
    network_mode: host
    ipc: host
    pid: host
    restart: unless-stopped
    environment:
      - ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}
    volumes:
      - scry_config:/home/scry/.config/scry
      - scry_audit:/var/log/scry

volumes:
  scry_config:
  scry_audit:
```

A turnkey reference compose with every tunable surfaced lives at
[`docker/docker-compose.yml`](https://github.com/phaneron-robotics/scry-connect/blob/master/docker/docker-compose.yml)
in the connect repo.

| Image tag | Resolves to |
|---|---|
| `humble`, `jazzy`, `kilted`, `lyrical`, `rolling` | Latest scry-connect on that ROS distro |
| `0.1.1-jazzy` (etc.) | Pinned scry-connect version |
| `latest` | `jazzy` |

Multi-arch: `linux/amd64` + `linux/arm64`. Works on x86 dev boxes and
Jetson / Raspberry Pi 4+ alike.

## Option C — pip install (for hacky one-off testing)

```bash
pip install scry-connect && scry-connect
```

The connect starts on port **5339** in **open mode on RFC1918 / loopback**
(rejects callers from public IPs by default). Open Scry on your phone
and either scan the QR the connect prints, or enter the robot's IP
address manually.

This path **doesn't survive reboot.** Use it for quick testing only.
For anything persistent, pick Option A or B.

## Verify the install

On the robot, check the connect is listening:

```bash
curl -s http://localhost:5339/health
# → {"status":"ok","version":"0.1.1","ros_distro":"jazzy"}
```

If you see the JSON above, you're done. Move on to
[Pair the phone and robot](pair.md).

## Security model

By default, scry-connect:

- **Listens on `0.0.0.0:5339`** but **rejects callers whose source IP
  isn't private (RFC1918 / loopback)**. This blocks accidental
  internet exposure if you forget a firewall rule.
- **Requires a paired token** for any "write" tool (set parameter,
  call service, publish to topic). Read tools (list topics, inspect
  nodes, etc.) work without pairing.
- **Logs every tool call** to `/var/log/scry/audit.log` with the
  caller IP, tool name, and approval state.

To require a paired token for *all* requests including reads:

```bash
scry-connect --token         # auto-generates and prints a QR-pairable token
```

For mutual TLS (recommended for production deployments):

```bash
scry-connect --tls --cert /path/to/cert.pem --key /path/to/key.pem
```

See the [scry-connect README](https://github.com/phaneron-robotics/scry-connect#security)
for the full security envelope.

## Troubleshooting

??? failure "ImportError: No module named rclpy"
    ROS 2 isn't sourced in the shell that ran the install. Source
    `setup.bash` from your distro:

    ```bash
    source /opt/ros/jazzy/setup.bash
    ```

    Then re-run the install. The Docker path doesn't have this issue
    because the container ships with ROS 2 already sourced.

??? failure "Port 5339 already in use"
    Another scry-connect is probably already running. Find and stop
    it:

    ```bash
    ss -tlnp | grep 5339
    systemctl --user stop scry-connect
    ```

    The systemd path runs as a `--user` service, not system-wide.

??? failure "Phone can't reach the robot"
    Triple-check:

    - Phone and robot on the **same WiFi network** (some routers
      isolate guest WiFi from main WiFi)
    - Robot's WiFi has a **private IP** (`192.168.x.x`, `10.x.x.x`,
      or `172.16-31.x.x`). Public IPs are rejected by default.
    - The robot's firewall isn't dropping `:5339`. On Ubuntu:
      `sudo ufw allow 5339/tcp`.

## Next

You have a running connect. Time to [pair it with the phone](pair.md).
