from lambda_fn.app import shorten_handler, redirect_handler
import json

def run():
    ev1 = {"body": json.dumps({"url":"https://example.com"}),
           "headers":{"host":"localhost:8000","x-forwarded-proto":"http"}}
    r1 = shorten_handler(ev1, None)
    print("Shorten:", r1)
    code = json.loads(r1["body"])["code"]
    r2 = redirect_handler({"pathParameters":{"code":code}}, None)
    print("Resolve:", r2)

if __name__ == "__main__":
    run()
