# Deploy: Serverless URL Shortener (Lambda + API Gateway + DynamoDB)

## What this does
- DynamoDB table
- Lambda function (Python) built from `lambda/`
- HTTP API Gateway with two routes:
  - POST /shorten → Lambda (create short code)
  - GET /{code}   → Lambda (resolve)

## Prereqs
- Add GitHub repo secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`

## Usage
- Commit this `infra/` and `.github/workflows/deploy.yml` to your repo (with `lambda/app.py` at project root as before).
- Push to `main` → workflow zips the Lambda code, uploads via Terraform, and outputs the API endpoint.
