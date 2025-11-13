import json, datetime, os
import azure.functions as func

def main(req: func.HttpRequest) -> func.HttpResponse:
    now = datetime.datetime.utcnow().isoformat() + "Z"
    demo_secret = os.getenv("DEMO_SECRET", "(no secret)")
    payload = {
        "service": "ehr-analytics-demo",
        "timestamp": now,
        "metrics": {"admissions_today": 42, "avg_er_wait_mins": 18, "discharges": 37},
        "kv_demo_secret": demo_secret[:6] + "***",
        "note": "Synthetic data for interview demo"
    }
    return func.HttpResponse(json.dumps(payload), mimetype="application/json")
