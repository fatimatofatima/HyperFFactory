#!/usr/bin/env python3
import os
import sys
import json
import time
import hashlib
from urllib.parse import urlparse, urljoin
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
from html.parser import HTMLParser

class LinkExtractor(HTMLParser):
    def __init__(self, base_url):
        super().__init__()
        self.base_url = base_url
        self.links = set()

    def handle_starttag(self, tag, attrs):
        if tag.lower() != 'a':
            return
        href = None
        for k, v in attrs:
            if k.lower() == 'href':
                href = v
                break
        if not href:
            return
        href = urljoin(self.base_url, href)
        self.links.add(href)

class SpiderConfig:
    def __init__(self, data):
        self.seeds = data.get("seeds", [])
        self.allowed_domains = data.get("allowed_domains", [])
        self.max_depth = int(data.get("max_depth", 1))
        self.max_pages = int(data.get("max_pages", 50))
        self.user_agent = data.get("user_agent", "SmartFriendSpider/1.0")
        self.output_root = data.get("output_root", "/opt/smartfriend-suite/var/knowledge/raw_spider")

def load_config(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return SpiderConfig(data)

def is_allowed(url, allowed_domains):
    try:
        netloc = urlparse(url).netloc
    except Exception:
        return False
    if not allowed_domains:
        return True
    return any(netloc.endswith(d) for d in allowed_domains)

def fetch(url, user_agent, timeout=15):
    req = Request(url, headers={"User-Agent": user_agent})
    with urlopen(req, timeout=timeout) as resp:
        content_type = resp.headers.get("Content-Type", "")
        if "text/html" not in content_type:
            return None, None
        body = resp.read()
        encoding = "utf-8"
        if "charset=" in content_type:
            try:
                encoding = content_type.split("charset=")[-1].split(";")[0].strip()
            except Exception:
                pass
        try:
            text = body.decode(encoding, errors="replace")
        except LookupError:
            text = body.decode("utf-8", errors="replace")
        return text, resp.geturl()

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def save_page(output_root, url, depth, html_text):
    parsed = urlparse(url)
    domain = parsed.netloc or "unknown"
    safe_domain = domain.replace(":", "_")
    day = time.strftime("%Y%m%d")
    base_dir = os.path.join(output_root, safe_domain, day)
    ensure_dir(base_dir)
    h = hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]
    filename = f"{h}_d{depth}.html"
    filepath = os.path.join(base_dir, filename)
    meta_path = os.path.join(base_dir, "index.jsonl")
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(html_text)
    record = {
        "url": url,
        "depth": depth,
        "file": filename,
        "ts": int(time.time())
    }
    with open(meta_path, "a", encoding="utf-8") as mf:
        mf.write(json.dumps(record, ensure_ascii=False) + "\n")
    return filepath

def log(msg):
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, flush=True)
    log_path = "/opt/smartfriend-suite/var/logs/spider.log"
    try:
        ensure_dir(os.path.dirname(log_path))
        with open(log_path, "a", encoding="utf-8") as lf:
            lf.write(line + "\n")
    except Exception:
        pass

def crawl(config):
    visited = set()
    queue = []
    for s in config.seeds:
        queue.append((s, 0))
    pages = 0

    while queue and pages < config.max_pages:
        url, depth = queue.pop(0)
        if url in visited:
            continue
        visited.add(url)
        if depth > config.max_depth:
            continue
        if not is_allowed(url, config.allowed_domains):
            log(f"SKIP (domain not allowed): {url}")
            continue
        log(f"FETCH [{depth}] {url}")
        try:
            html_text, final_url = fetch(url, config.user_agent)
        except (HTTPError, URLError) as e:
            log(f"ERROR fetch {url}: {e}")
            continue
        except Exception as e:
            log(f"ERROR fetch {url}: {e}")
            continue
        if not html_text:
            log(f"SKIP (non-html or empty): {url}")
            continue

        save_page(config.output_root, final_url or url, depth, html_text)
        pages += 1

        extractor = LinkExtractor(final_url or url)
        try:
            extractor.feed(html_text)
        except Exception as e:
            log(f"ERROR parsing links from {url}: {e}")
            continue

        for link in extractor.links:
            if link not in visited:
                queue.append((link, depth + 1))

    log(f"DONE: crawled {pages} pages, visited={len(visited)} urls")

def main():
    config_path = os.environ.get("SPIDER_CONFIG", "")
    if len(sys.argv) > 1:
        config_path = sys.argv[1]
    if not config_path:
        print("Usage: spider_main.py /path/to/spider.config.json", file=sys.stderr)
        sys.exit(1)
    if not os.path.isfile(config_path):
        print(f"Config not found: {config_path}", file=sys.stderr)
        sys.exit(1)
    config = load_config(config_path)
    if not config.seeds:
        print("No seeds in config; nothing to crawl.", file=sys.stderr)
        sys.exit(0)
    crawl(config)

if __name__ == "__main__":
    main()
