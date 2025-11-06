# LLM Proxy code - shared ConfigMap
# This contains the proxy logic that forwards requests to the shared LLM

resource "kubernetes_config_map" "llm_proxy_code" {
  metadata {
    name      = "llm-proxy-code"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  data = {
    "proxy.py" = <<-EOT
#!/usr/bin/env python3
"""
LLM Proxy Service for Tenant
Forwards requests to shared LLM with tenant-specific system prompt
"""

import os
import requests
from flask import Flask, request, jsonify

app = Flask(__name__)

# Configuration from environment
LLM_SERVICE_URL = os.getenv("LLM_SERVICE_URL", "http://llm-gateway.monitoring:5000")
TENANT_NAME = os.getenv("TENANT_NAME", "unknown")
COMPANY_NAME = os.getenv("COMPANY_NAME", "unknown")

# Load tenant-specific system prompt
SYSTEM_PROMPT = ""
try:
    with open("/app/prompt/system_prompt.txt", "r") as f:
        SYSTEM_PROMPT = f.read().strip()
except:
    SYSTEM_PROMPT = f"You are a helpful assistant for {COMPANY_NAME}."

print(f"[{TENANT_NAME}] Proxy initialized with system prompt from config")
print(f"[{TENANT_NAME}] Forwarding to LLM at {LLM_SERVICE_URL}")


@app.route("/health", methods=["GET"])
def health():
    """Health check"""
    try:
        # Check if LLM service is reachable
        response = requests.get(f"{LLM_SERVICE_URL}/health", timeout=5)
        return jsonify({
            "status": "healthy",
            "tenant": TENANT_NAME,
            "llm_status": response.json() if response.ok else "unreachable"
        }), 200
    except:
        return jsonify({
            "status": "unhealthy",
            "tenant": TENANT_NAME,
            "error": "LLM service unreachable"
        }), 503


@app.route("/ask", methods=["POST"])
def ask():
    """
    Ask the LLM a question with tenant-specific context

    Request JSON:
    {
        "question": "What should we build?",
        "max_tokens": 512
    }

    Response:
    {
        "question": "...",
        "answer": "...",
        "tenant": "acme-corp",
        "system_prompt_used": "Design-first approach..."
    }
    """
    try:
        data = request.get_json()

        if not data or "question" not in data:
            return jsonify({"error": "Missing 'question' in request"}), 400

        question = data.get("question")
        max_tokens = data.get("max_tokens", 512)

        # Forward to shared LLM with tenant-specific system prompt
        llm_request = {
            "prompt": question,
            "system_prompt": SYSTEM_PROMPT,
            "max_tokens": max_tokens
        }

        response = requests.post(
            f"{LLM_SERVICE_URL}/infer",
            json=llm_request,
            timeout=120
        )

        if not response.ok:
            return jsonify({
                "error": f"LLM service error: {response.text}"
            }), response.status_code

        llm_response = response.json()

        # Wrap with tenant context
        return jsonify({
            "question": question,
            "answer": llm_response.get("response"),
            "tenant": TENANT_NAME,
            "company": COMPANY_NAME,
            "system_prompt_used": SYSTEM_PROMPT[:100] + "...",
            "model": llm_response.get("model"),
            "tokens_generated": llm_response.get("tokens_generated"),
            "mode": llm_response.get("mode", "unknown")
        }), 200

    except requests.Timeout:
        return jsonify({
            "error": "LLM inference timeout (model is thinking...)"
        }), 504
    except Exception as e:
        print(f"[{TENANT_NAME}] Error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/info", methods=["GET"])
def info():
    """Get tenant and LLM info"""
    return jsonify({
        "tenant": TENANT_NAME,
        "company": COMPANY_NAME,
        "system_prompt": SYSTEM_PROMPT,
        "llm_service": LLM_SERVICE_URL,
        "endpoints": ["/health", "/ask", "/info"]
    }), 200


if __name__ == "__main__":
    print(f"[{TENANT_NAME}] Starting LLM Proxy on 0.0.0.0:5002")
    app.run(host="0.0.0.0", port=5002, debug=False)
EOT
  }

  depends_on = [kubernetes_namespace.tenant]
}
