# XBloom + Claude

Let Claude create custom coffee and tea recipes for your XBloom Studio machine. Just tell Claude about your coffee or tea — or snap a photo of the bag — and it designs a recipe that syncs straight to your xBloom app.

No coding needed. Works on Claude desktop, mobile, and web.

---

## Get Started

### Step 1: Connect to Claude

Open Claude and add your server URL in your integrations settings (this is the
URL of your own deployment — see [Self-Hosting with Docker](#self-hosting-with-docker)):

```
https://your-server.example/
```

**Where to find it:**
- **Desktop app** — Settings > Integrations > Add
- **iPhone / Android** — Settings > Integrations > Add
- **claude.ai** — Profile > Settings > Integrations > Add

Approve the connection when prompted.

### Step 2: Sign in with your XBloom account

The first time you use it, Claude will ask for your XBloom email and password. This links your XBloom account so recipes go directly to **your** app. Your password is used once and **never saved**.

### Step 3: Start chatting

Ask Claude to make you a recipe. Here are some ideas:

**Coffee:**

> *"Here's a photo of my coffee bag. Make me a recipe for it."*

> *"I have a medium roast Colombian, 18g dose. I like it bright and clean."*

> *"That last brew was a little bitter — can you adjust?"*

**Tea:**

> *"Create a tea recipe for my hojicha, 5g, two steeps."*

> *"Make a green tea recipe — 3g sencha, 70°C, 60 second steep."*

> *"I want an oolong recipe with three steeps, getting hotter each time."*

**Manage:**

> *"Show me all my recipes."*

> *"Delete the old test recipe."*

Recipes sync instantly to the **xBloom iOS app** and are ready to brew.

### What can it do?

- **Coffee recipes** — Pour-over recipes for the Omni dripper using brewing science (Kasuya 4:6, Hoffmann, Rao, etc.)
- **Tea recipes** — Steep recipes for the Omni Tea Brewer with proper temperatures and steep times
- **Photo-to-recipe** — Take a photo of your coffee or tea bag, Claude reads the label and creates a recipe
- **Link-to-recipe** — Paste a product link, Claude pulls the details and designs a recipe
- **Taste adjustments** — Tell Claude it was too bitter/sour/weak and it tweaks the recipe
- **Manage recipes** — List, edit, and delete recipes right from the chat
- **Import recipes** — Grab any shared XBloom recipe by URL

### Privacy

- Your password is **never stored** — it's used once to log in, then thrown away
- Each user has their own account — nobody else can see or touch your recipes
- Session tokens are encrypted at rest

---

## Developer Guide

Everything below is for developers who want to self-host or modify the server.

### Tech Stack

- **Runtime**: Deno 2.x (self-contained, runs anywhere via Docker)
- **Protocol**: MCP 2.0 (Streamable HTTP + SSE)
- **Auth**: OAuth 2.0 + per-user XBloom login
- **Storage**: file-backed Deno KV (no external database)
- **Encryption**: AES-256-CBC (sessions) + RSA (API payloads, XBloom's key)

### MCP Tools

| Tool | Description |
|------|-------------|
| `xbloom_login` | Authenticate with your XBloom account |
| `xbloom_list_recipes` | List all your recipes with IDs |
| `xbloom_create_recipe` | Create a coffee recipe (Omni dripper) |
| `xbloom_create_tea_recipe` | Create a tea recipe (Omni Tea Brewer) |
| `xbloom_edit_recipe` | Update an existing recipe by ID |
| `xbloom_delete_recipe` | Permanently remove a recipe |
| `xbloom_fetch_recipe` | Import a recipe from a share URL |

### Self-Hosting with Docker

The MCP server is a single self-contained Deno app. **No external database is
required** — sessions are stored in a file-backed
[Deno KV](https://docs.deno.com/deploy/kv/manual/) store inside the container.
Mount a volume at `/data` to persist them across restarts.

The container listens on **port 2566** ("BLOOM" on a phone keypad).

#### Build & run with Docker Compose

```bash
cp .env.example .env
# edit .env — set SESSION_ENCRYPTION_KEY (e.g. `openssl rand -hex 32`)
docker compose up -d --build
```

Check it's healthy:

```bash
curl http://localhost:2566/        # -> {"name":"xbloom-mcp","status":"ok"}
docker compose logs -f xbloom-mcp
```

#### Or with plain Docker

```bash
docker build -t xbloom-mcp .
docker run -d -p 2566:2566 \
  -e SESSION_ENCRYPTION_KEY="$(openssl rand -hex 32)" \
  -e MCP_BASE_URL="https://mcp.example.com" \
  -v xbloom-data:/data \
  --name xbloom-mcp xbloom-mcp
```

#### Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SESSION_ENCRYPTION_KEY` | yes | Secret used to derive the AES key that encrypts stored sessions. Use a long random string. Changing it invalidates existing sessions (users must log in again) |
| `MCP_BASE_URL` | no | Public URL the server is reachable at, used for OAuth discovery metadata. Set to your own domain when self-hosting; defaults to `http://localhost:2566` |
| `PORT` | no | Port to listen on (default `2566` in the image) |
| `KV_PATH` | no | Path to the Deno KV session file (default `/data/xbloom-kv.sqlite` in the image) |
| `ALLOWED_EMAILS` | no | Comma-separated allowlist of XBloom emails permitted to log in. **Recommended when exposed publicly** — locks the server to your own account so it can't be abused as a login relay. Empty = allow any |
| `RATE_LIMIT_MAX` | no | Max requests per IP per window before `429` (default `120`) |
| `RATE_LIMIT_WINDOW_MS` | no | Rate-limit window in ms (default `60000`) |

> Put the container behind a TLS-terminating reverse proxy (Caddy, nginx,
> Traefik, …) and point `MCP_BASE_URL` at the public HTTPS URL. Then add that
> URL in Claude integrations:
>
> ```
> https://mcp.example.com
> ```

#### Exposing it publicly? Read this

To use Claude **web or mobile**, the server must be reachable from the internet
(Anthropic's cloud connects to it — `localhost` won't work). When exposed:

- **Always serve over HTTPS** (a reverse proxy or tunnel like Cloudflare Tunnel
  provides this) — `xbloom_login` sends your password, so plaintext HTTP would
  leak it in transit.
- **Set `ALLOWED_EMAILS`** to your own XBloom email so strangers can't use your
  server as a login relay.
- Rate limiting is on by default (`RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW_MS`).

Your XBloom recipes are not directly exposed: every connection starts with an
empty session, and nothing works until someone logs in with *your* XBloom
credentials.

### Recipe Parameters

**Coffee** (Omni dripper):

| Parameter | Range | Notes |
|-----------|-------|-------|
| `dose_g` | 1–31 | Coffee dose in grams |
| `grind_size` | 40–120 | Lower = finer |
| `grind_rpm` | 60–120 | Grinder speed |
| `temperature_c` | 40–95 | Water temperature |
| `flow_rate` | 3.0–3.5 | mL/s |
| `pattern` | centered, circular, spiral | Pour pattern |
| `pause_seconds` | 0–255 | Pause between pours |

**Tea** (Omni Tea Brewer):

| Parameter | Range | Notes |
|-----------|-------|-------|
| `dose_g` | 1–10 | Tea dose in grams |
| `volume_ml` | 1–90 | Water per steep (machine adds ~30ml for siphon) |
| `temperature_c` | 65–100 | Green: 70-80, White: 75-85, Oolong: 85-95, Black: 90-100 |
| `steep_seconds` | 0–360 | Up to 6 minutes per steep |
| `steeps` | 1–3 | Number of steeps |

### Project Structure

```
xbloom-agent/
├── Dockerfile                              # Container image for the MCP server
├── docker-compose.yml                      # One-command local/self-host run
├── .env.example                            # Env vars for Docker
├── xbloom-mcp-remote/
│   └── server/
│       ├── deno.json                       # Deno config (enables KV)
│       └── index.ts                        # MCP server (OAuth + tools + SSE + KV storage)
└── xbloom-recipes/
    └── claude-project/
        ├── custom-instructions.md          # Claude project instructions
        └── xbloom-brewing-reference.md     # Coffee brewing science reference
```

### Security

- Passwords are **never stored** — used once for XBloom API login, then discarded
- Session tokens are **AES-256 encrypted** at rest using an HMAC-SHA256 derived key
- The encryption key comes from `SESSION_ENCRYPTION_KEY`, kept out of the codebase
- Error messages are sanitized — no internal API details leaked

## License

MIT
