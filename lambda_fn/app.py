import json, os, re, random, string, boto3
from botocore.config import Config

TABLE = os.getenv("TABLE", "url_shortener")  # <— uses Terraform env or falls back locally
_LOCAL_STORE = {}

def _is_valid_url(u: str) -> bool:
    return bool(re.match(r'https?://', u))

def _gen_code(n=6) -> str:
    return ''.join(random.choices(string.ascii_letters + string.digits, k=n))

def _dynamodb():
    endpoint = os.getenv("AWS_ENDPOINT_URL")  # LocalStack support
    cfg = Config(retries={'max_attempts': 3, 'mode': 'standard'})
    return boto3.resource("dynamodb", endpoint_url=endpoint, config=cfg)

def shorten_handler(event, context=None):
    body = event.get('body')
    if isinstance(body, str):
        try:
            body = json.loads(body)
        except Exception:
            return {"statusCode": 400, "body": json.dumps({"error": "Invalid JSON"})}
    url = (body or {}).get('url')
    if not url or not _is_valid_url(url):
        return {"statusCode": 400, "body": json.dumps({"error": "Invalid url"})}

    code = _gen_code()
    host = event.get('headers', {}).get('host', 'localhost')
    proto = event.get('headers', {}).get('x-forwarded-proto', 'http')
    short = f"{proto}://{host}/{code}"

    if os.getenv("AWS_ENDPOINT_URL") or os.getenv("AWS_EXECUTION_ENV"):
        # Write to DynamoDB
        table = _dynamodb().Table(TABLE)
        table.put_item(Item={"code": code, "url": url})
    else:
        _LOCAL_STORE[code] = url

    return {"statusCode": 201, "body": json.dumps({"code": code, "shortUrl": short})}

def redirect_handler(event, context=None):
    code = event.get('pathParameters', {}).get('code')
    if not code:
        return {"statusCode": 400, "body": json.dumps({"error": "Missing code"})}

    target = None
    if os.getenv("AWS_ENDPOINT_URL") or os.getenv("AWS_EXECUTION_ENV"):
        table = _dynamodb().Table(TABLE)
        resp = table.get_item(Key={"code": code})
        target = resp.get("Item", {}).get("url")
    else:
        target = _LOCAL_STORE.get(code)

    if not target:
        return {"statusCode": 404, "body": json.dumps({"error": "Not found"})}
    return {"statusCode": 200, "body": json.dumps({"target": target})}
