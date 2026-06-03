# XBloom MCP Server — Docker image
# Runs the self-contained Deno MCP server (OAuth + SSE + Streamable HTTP).
# Session persistence still uses Supabase (REST API), so provide SUPABASE_URL
# and SUPABASE_SERVICE_ROLE_KEY at runtime. See README "Run with Docker".

FROM denoland/deno:2.1.4

WORKDIR /app

# The MCP server is a single self-contained file plus its import map.
COPY xbloom-mcp-remote/supabase/functions/xbloom-mcp/deno.json ./deno.json
COPY xbloom-mcp-remote/supabase/functions/xbloom-mcp/index.ts ./index.ts

# Cache dependencies as the non-root "deno" user so the runtime can read them.
RUN chown -R deno:deno /app
USER deno
RUN deno cache index.ts

# Deno.serve() listens on 0.0.0.0:8000 by default.
EXPOSE 8000

# --allow-net: serve + outbound fetch to XBloom/Supabase APIs
# --allow-env: read SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY / MCP_BASE_URL
CMD ["deno", "run", "--allow-net", "--allow-env", "index.ts"]
