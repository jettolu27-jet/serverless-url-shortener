# Serverless URL Shortener (Lambda + API Gateway + DynamoDB)

**What this shows**
- Lambda-style handlers (Python)
- DynamoDB read/write logic (works with LocalStack too)
- Unit tests with pytest
- GitHub Actions CI (pytest + Terraform validate)

## Local quickstart
```bash
pip install -r requirements.txt
pytest -q
python local_dev.py
```

## LocalStack (optional)
```bash
docker compose up -d localstack
# In another terminal, you can create a DynamoDB table:
awslocal dynamodb create-table   --table-name url_shortener   --attribute-definitions AttributeName=code,AttributeType=S   --key-schema AttributeName=code,KeyType=HASH   --billing-mode PAY_PER_REQUEST
# then run tests with AWS_ENDPOINT_URL pointing to LocalStack:
set AWS_ENDPOINT_URL=http://localhost:4566  (Windows)
export AWS_ENDPOINT_URL=http://localhost:4566 (mac/Linux)
pytest -q
```

## Terraform
`infra/main.tf` has a working table resource. Extend with Lambda/API Gateway when ready.
