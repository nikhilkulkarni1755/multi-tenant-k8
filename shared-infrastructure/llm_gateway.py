#!/usr/bin/env python3
"""
LLM Gateway Service
Proxies requests to external LLM (OpenAI API)
Provides centralized API key management and tenant isolation
"""

import os
import requests
from flask import Flask, request, jsonify

app = Flask(__name__)

# Configuration from environment
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_ENDPOINT = os.getenv("OPENAI_ENDPOINT", "https://api.openai.com/v1/chat/completions")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-3.5-turbo")

print(f"LLM Gateway Configuration:")
print(f"  Endpoint: {OPENAI_ENDPOINT}")
print(f"  Model: {OPENAI_MODEL}")
print(f"  API Key: {'[SET]' if OPENAI_API_KEY else '[NOT SET]'}")


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "backend": "openai",
        "model": OPENAI_MODEL,
        "api_key_configured": bool(OPENAI_API_KEY)
    }), 200


@app.route("/infer", methods=["POST"])
def infer():
    """
    Proxy inference requests to OpenAI API

    Request JSON:
    {
        "prompt": "User question/instruction",
        "system_prompt": "Custom system instructions for this tenant",
        "max_tokens": 256,
        "tenant": "acme-corp" (optional, for logging)
    }

    Response:
    {
        "prompt": "Original prompt",
        "system_prompt": "System prompt used",
        "response": "LLM response",
        "tenant": "acme-corp",
        "model": "gpt-3.5-turbo"
    }
    """
    try:
        data = request.get_json()

        if not data or "prompt" not in data:
            return jsonify({"error": "Missing 'prompt' in request"}), 400

        user_prompt = data.get("prompt")
        system_prompt = data.get("system_prompt", "You are a helpful assistant.")
        max_tokens = data.get("max_tokens", 256)
        tenant = data.get("tenant", "unknown")

        # Check if API key is configured
        if not OPENAI_API_KEY:
            return jsonify({
                "error": "OpenAI API key not configured",
                "prompt": user_prompt,
                "system_prompt": system_prompt,
                "tenant": tenant
            }), 500

        # Prepare OpenAI API request
        headers = {
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type": "application/json"
        }

        payload = {
            "model": OPENAI_MODEL,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "max_tokens": max_tokens,
            "temperature": 0.7
        }

        print(f"[{tenant}] Calling OpenAI API...")

        # Call OpenAI API
        response = requests.post(
            OPENAI_ENDPOINT,
            headers=headers,
            json=payload,
            timeout=30
        )

        if response.status_code != 200:
            print(f"[{tenant}] OpenAI API error: {response.status_code}")
            print(f"Response: {response.text}")
            return jsonify({
                "error": f"OpenAI API error: {response.status_code}",
                "details": response.text
            }), response.status_code

        # Extract response
        response_data = response.json()
        llm_response = response_data["choices"][0]["message"]["content"]

        print(f"[{tenant}] Response received ({len(llm_response)} chars)")

        return jsonify({
            "prompt": user_prompt,
            "system_prompt": system_prompt,
            "response": llm_response,
            "tenant": tenant,
            "model": OPENAI_MODEL,
            "backend": "openai"
        }), 200

    except requests.exceptions.Timeout:
        print(f"[{tenant}] OpenAI API timeout")
        return jsonify({"error": "OpenAI API timeout"}), 504
    except Exception as e:
        print(f"Error during inference: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/info", methods=["GET"])
def info():
    """Get gateway information"""
    return jsonify({
        "service": "LLM Gateway",
        "backend": "openai",
        "model": OPENAI_MODEL,
        "endpoint": OPENAI_ENDPOINT,
        "api_key_configured": bool(OPENAI_API_KEY),
        "available_endpoints": ["/health", "/infer", "/info"]
    }), 200


if __name__ == "__main__":
    print(f"Starting LLM Gateway on 0.0.0.0:5000")
    print(f"Backend: OpenAI ({OPENAI_MODEL})")
    print(f"Endpoints: /health, /infer, /info")
    app.run(host="0.0.0.0", port=5000, debug=False)
