# Provider Configuration

LiteLLM centralizes provider credentials in the gateway. Application teams call the gateway with LiteLLM keys instead of owning upstream provider keys.

## OpenAI

Set:

```sh
OPENAI_API_KEY=sk-...
```

Configured models:

- `gpt-4o-mini`
- `gpt-4o`

Example request:

```sh
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-dev-master-key-change-me" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o-mini","messages":[{"role":"user","content":"Hello"}]}'
```

## Anthropic

Set:

```sh
ANTHROPIC_API_KEY=sk-ant-...
```

Configured model:

- `claude-3-5-sonnet`

## Ollama

Ollama is included as an optional Compose profile:

```sh
docker compose --profile local-models up -d
docker compose exec ollama ollama pull llama3.1
```

Configured model:

- `llama3-local`

LiteLLM routes this to `http://ollama:11434`.

## Text Generation Inference

Set:

```sh
TGI_API_BASE=http://tgi:8080
HUGGINGFACE_API_KEY=
```

Configured model:

- `tgi-local`

If TGI runs outside this Compose project, set `TGI_API_BASE` to the reachable URL from inside the LiteLLM container.

## Adding A New Provider

Add an entry to `litellm/config.yaml`:

```yaml
model_list:
  - model_name: groq-llama
    litellm_params:
      model: groq/llama-3.1-70b-versatile
      api_key: os.environ/GROQ_API_KEY
```

Then add the provider key to `.env` and restart LiteLLM:

```sh
docker compose restart litellm
```

Keep model names stable once client services depend on them. If the upstream model changes, update only the `litellm_params.model` value when possible.
