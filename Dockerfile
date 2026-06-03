# XBloom MCP Server — Docker image
# Runs the self-contained Deno MCP server (OAuth + SSE + Streamable HTTP).
# Sessions are stored in a self-contained, file-backed Deno KV store — no
# external database required. Set SESSION_ENCRYPTION_KEY at runtime and mount
# a volume at /data to persist sessions. See README "Run with Docker".

FROM denoland/deno:2.1.4

WORKDIR /app

# The MCP server is a single self-contained file plus its import map.
COPY xbloom-mcp-remote/supabase/functions/xbloom-mcp/deno.json ./deno.json
COPY xbloom-mcp-remote/supabase/functions/xbloom-mcp/index.ts ./index.ts

# /data holds the Deno KV session store (mount a volume here to persist it).
RUN mkdir -p /data && chown -R deno:deno /app /data
USER deno

# Cache dependencies as the non-root "deno" user so the runtime can read them.
RUN deno cache index.ts

# Port 2566 spells "BLOOM" on a phone keypad (B-L-O-O = 2-5-6-6).
ENV PORT=2566
ENV KV_PATH=/data/xbloom-kv.sqlite
EXPOSE 2566
VOLUME ["/data"]

# --allow-net:   serve + outbound fetch to the XBloom API
# --allow-env:   read PORT / KV_PATH / SESSION_ENCRYPTION_KEY / MCP_BASE_URL
# --allow-read / --allow-write: local Deno KV store file
# --unstable-kv: enables Deno.openKv()
CMD ["deno", "run", "--allow-net", "--allow-env", "--allow-read", "--allow-write", "--unstable-kv", "index.ts"]
