---
hide:
  - navigation
  - toc
---

# Scry

> Your ROS 2 robot in your pocket — AI-first debugging from Android.

Scry is an open-source toolkit that connects any ROS 2 robot to an AI agent
running on your phone. Ask questions in plain English, by voice, or with a
screenshot — the agent introspects your robot's topics, nodes, services,
parameters, and diagnostics live over WiFi.

<div class="grid cards" markdown>

-   :material-rocket-launch:{ .lg .middle } **Get started**

    ---

    Install the Android app, run `scry-connect` on the robot, pair, ask
    your first question. About 15 minutes end to end.

    [:octicons-arrow-right-24: Get started](get-started/index.md)

-   :material-robot:{ .lg .middle } **Use Scry**

    ---

    Chat with the agent, attach logs and images, set background
    threshold monitors, send 👍 / 👎 feedback on every reply.

    [:octicons-arrow-right-24: Use Scry](use/index.md)

-   :material-sitemap:{ .lg .middle } **Architecture**

    ---

    Phone is the thick client, robot just runs an MCP server. How the
    tiered context system works. Why no cloud backend.

    [:octicons-arrow-right-24: Architecture](architecture/index.md)

-   :material-book-open-page-variant:{ .lg .middle } **Reference**

    ---

    The ~99 MCP tools `scry-connect` exposes, what each one returns,
    which require user approval. App permissions.

    [:octicons-arrow-right-24: Reference](reference/index.md)

-   :material-account-cog:{ .lg .middle } **Operator**

    ---

    Run a beta. Cut a release. Audit security. The runbooks Phaneron
    Robotics uses internally.

    [:octicons-arrow-right-24: Operator](operator/index.md)

-   :material-scale-balance:{ .lg .middle } **Legal**

    ---

    Privacy policy, Play Store Data Safety form, security policy,
    license. The boring but important stuff.

    [:octicons-arrow-right-24: Legal](legal/index.md)

</div>

---

## How it works

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│                 │  HTTPS  │                 │  rclpy  │                 │
│   Android app   │ ◄─────► │  scry-connect   │ ◄─────► │   ROS 2 graph   │
│   (Kotlin/CMP)  │   MCP   │   (Python MCP)  │         │   (any DDS)     │
│                 │   SSE   │                 │         │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

The phone is the thick client: AI provider, tool routing, rich rendering,
monitors, and fleet coordination all happen on-device. The robot just runs
a small Python server (`scry-connect`) that exposes ROS 2 capabilities as
MCP tools.

**No cloud backend.** **No telemetry.** Your AI keys, your robot, your LAN.

## What you need

- **A phone** running Android 9 (API 28) or newer
- **A ROS 2 robot** running Humble, Iron, Jazzy, Kilted, or Rolling
- **An AI provider key** — OpenRouter (one key, 300+ models) or any of
  Claude, OpenAI, Gemini. Or run a local Ollama for fully offline.
- **Both on the same WiFi.** Phone and robot talk directly; nothing
  routes through the cloud.

## Open source

| Component | Repo | License |
|---|---|---|
| Android app | [`scry-android`](https://github.com/phaneron-robotics/scry-android) | Apache 2.0 |
| Robot MCP server | [`scry-connect`](https://github.com/phaneron-robotics/scry-connect) | Apache 2.0 |
| Docs site (this one) | [`scry-web`](https://github.com/phaneron-robotics/scry-web) | Apache 2.0 |
| Brand assets | [`scry-brand`](https://github.com/phaneron-robotics/scry-brand) | CC-BY-4.0 |

Maintained by [Phaneron Robotics, Inc.](https://phaneronrobotics.com/)
