# scry-web

Public docs + install guide + privacy pages for [Scry](https://github.com/phaneron-robotics/scry-android).

Built with [MkDocs Material](https://squidfunk.github.io/mkdocs-material/).
Lives at **https://phaneron-robotics.github.io/scry-web/**.

## Layout

```
docs/
├── index.md                 # Landing
├── get-started/             # Install + first session
├── use/                     # Day-to-day feature docs
├── architecture/            # How Scry works under the hood
├── reference/               # MCP tools, permissions, exhaustive lookups
├── operator/                # Beta testing, release runbook, security audit
└── legal/                   # Privacy, data safety, security policy, license
mkdocs.yml                   # Site config + navigation
requirements.txt             # Pinned MkDocs + plugins for reproducible CI
.github/workflows/deploy.yml # Auto-deploy on push to master
```

## Local development

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
mkdocs serve
# Open http://127.0.0.1:8000
```

`mkdocs serve` watches the docs dir and live-reloads on every edit.

## Deploy

Pushes to `master` trigger `.github/workflows/deploy.yml` which builds
the static site with `mkdocs build --strict` and publishes to GitHub
Pages.

One-time setup (per repo):

1. Push this branch to GitHub.
2. Repo Settings → **Pages** → Source = **GitHub Actions**.
3. Wait for the first deploy run to finish.

## Contributing

Open a PR on this repo. Page tone: pragmatic, "explain what it is and
what to do," not marketing-speak. Mirror the writing in adjacent pages.

## License

Code (config, workflow): Apache 2.0. Prose content: same.
Brand assets (logo, mark): CC-BY-4.0 per [scry-brand](https://github.com/phaneron-robotics/scry-brand).
