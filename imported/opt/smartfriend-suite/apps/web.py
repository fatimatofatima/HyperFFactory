from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import os
import time

app = FastAPI(
    title="SmartFriend Suite Web UI",
    version="1.0.0",
    description="Minimal dashboard placeholder for SmartFriend Suite."
)

def _link(path: str, label: str) -> str:
    return f'<li><a href="{path}">{label}</a></li>'

@app.get("/", response_class=HTMLResponse)
async def index():
    items = [
        _link("/core/health", "Core API /health (via nginx)"),
        _link("/unified/health", "Unified API /health"),
        _link("/memory/health", "Memory API /health"),
        _link("/memory/stats", "Memory /stats"),
        _link("/nginx-health", "Nginx /nginx-health"),
    ]
    html = f"""
    <html>
      <head>
        <meta charset="utf-8" />
        <title>SmartFriend Suite Dashboard</title>
      </head>
      <body>
        <h1>SmartFriend Suite – Dashboard</h1>
        <p>Environment: {os.getenv("SF_ENV", "unknown")}</p>
        <p>Time: {time.strftime("%Y-%m-%d %H:%M:%S")}</p>
        <h2>Quick Links</h2>
        <ul>
          {''.join(items)}
        </ul>
      </body>
    </html>
    """
    return html
