import json
import os
import azure.functions as func
import requests

def main(req: func.HttpRequest) -> func.HttpResponse:
    text = req.params.get('text') or (req.get_body().decode('utf-8') if req.get_body() else '')
    if not text:
        text = 'Patient presents with mild chest pain; EKG normal; recommend rest and follow-up.'

    endpoint = os.getenv('AI_ENDPOINT')  # e.g., https://your-openai-like-endpoint/summarize
    key = os.getenv('AI_KEY')

    if endpoint and key:
        try:
            headers = {"api-key": key, "Content-Type": "application/json"}
            body = {"input": text}
            r = requests.post(endpoint, headers=headers, json=body, timeout=10)
            r.raise_for_status()
            data = r.json()
            summary = data.get('summary') or data
        except Exception as e:
            summary = {"_error": str(e), "mock": True, "summary": text[:120] + "..."}
    else:
        summary = {"mock": True, "summary": f"Summary: {text[:100]}..."}

    return func.HttpResponse(json.dumps(summary), status_code=200, mimetype="application/json")
