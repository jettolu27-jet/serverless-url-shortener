# tests/test_app.py
import sys
from pathlib import Path

# Ensure repo root is on sys.path (CI-safe)
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from lambda_fn.app import shorten_handler, redirect_handler
import json

def test_roundtrip_local():
    ev1 = {"body": json.dumps({"url":"https://example.com"}),
           "headers":{"host":"localhost","x-forwarded-proto":"http"}}
    r1 = shorten_handler(ev1, None)
    assert r1["statusCode"] == 201
    code = json.loads(r1["body"])["code"]
    r2 = redirect_handler({"pathParameters":{"code":code}}, None)
    assert r2["statusCode"] == 200
    assert "example.com" in json.loads(r2["body"])["target"]
