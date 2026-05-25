# Scry — AI Provider Strategy

## Problem

Requiring users to generate a Claude API key creates friction:
- Need Anthropic account + payment method
- Pay per-token (separate from Claude Pro subscription)
- API key management complexity
- Not all users want cloud-based AI

## Solution: Multi-Provider with Easy Onboarding

Scry supports multiple AI providers behind a unified `AiClient` interface. The MCP tool-call proxy loop stays the same regardless of provider — only the AI endpoint changes. All four providers are shipping; pick from the top-bar chip in the chat screen.

## Supported Providers

### 1. Ollama (Local, Free) — Default for Zero Friction

| Property | Value |
|----------|-------|
| Cost | Free |
| API Key Required | No |
| Internet Required | No |
| Runs On | Robot, local machine, or any reachable host |
| Default model | `qwen2.5:7b` |
| Other tested models | Llama 3.x, Mistral, LLaVA, qwen2.5-vl |
| Tool Calling | Supported (Llama 3.1+, Qwen 2.5+) |
| Vision | Supported (LLaVA, qwen2.5-vl) |
| Wire format | NDJSON + atomic `tool_calls` |

**Setup**: User installs Ollama on the robot or any machine on the network. Scry stores the base URL and model name in Settings (encrypted prefs).

**Trade-offs**:
- Weaker reasoning than Claude / GPT-4o
- Tool-calling accuracy lower (may need retries)
- Good enough for basic debugging ("what topics are active?", "show me the camera")
- Excellent for air-gapped / offline environments

### 2. Claude API (Anthropic) — Recommended for Best Experience

| Property | Value |
|----------|-------|
| Cost | Pay-per-token |
| API Key Required | Yes |
| Internet Required | Yes |
| Default model | `claude-sonnet-4-6` |
| Other models | `claude-opus-4-6` (highest quality), `claude-haiku-4-5-20251001` (fast, cheap) |
| Tool Calling | Best-in-class |
| Vision | Yes (excellent) |
| Wire format | SSE + `input_json_delta` piecewise tool args |

**Why recommended**: Best tool-calling accuracy, best multi-modal reasoning, best at complex diagnosis chains and multi-step plans.

### 3. OpenAI API — Good Alternative

| Property | Value |
|----------|-------|
| Cost | Pay-per-token |
| API Key Required | Yes |
| Internet Required | Yes |
| Default model | `gpt-4o-mini` |
| Other models | `gpt-4o`, `gpt-4.1` |
| Tool Calling | Excellent |
| Vision | Yes |
| Wire format | SSE + piecewise `tool_calls.function.arguments` |

**Why included**: Many developers already have OpenAI API keys.

### 4. Google Gemini API — Free Tier Available

| Property | Value |
|----------|-------|
| Cost | Free tier (15 RPM), then pay-per-token |
| API Key Required | Yes |
| Internet Required | Yes |
| Default model | `gemini-2.0-flash` |
| Other models | `gemini-2.5-pro` (higher quality) |
| Tool Calling | Good |
| Vision | Yes |
| Wire format | SSE + atomic `functionCall` parts |

**Why included**: Generous free tier means users can try AI features without any payment.

## Implementation

The shipped interface lives in [`android/app/src/main/java/com/scry/data/ai/AiModels.kt`](https://github.com/phaneron-robotics/scry-android/blob/master/app/src/main/java/com/scry/data/ai/AiModels.kt) and looks like:

```kotlin
interface AiClient {
    val providerName: String
    val supportsVision: Boolean
    val supportsToolCalling: Boolean

    fun chat(
        messages: List<Message>,
        tools: List<Tool>,
        systemPrompt: String,
        model: String,
    ): Flow<ChatEvent>
}

sealed class ChatEvent {
    data class TextDelta(val text: String) : ChatEvent()
    data class ToolCallStarted(val id: String, val tool: String, val input: JsonObject) : ChatEvent()
    data class ToolCallCompleted(val id: String) : ChatEvent()
    data class MessageComplete(val message: Message) : ChatEvent()
    data class Error(val error: Throwable) : ChatEvent()
}

// Shipped implementations (data/ai/)
class ClaudeClient(...) : AiClient
class OpenAiClient(...) : AiClient
class GeminiClient(...) : AiClient
class OllamaClient(...) : AiClient
```

`AiProxyLoop` calls `chat(...)` once per turn, parses the resulting
event stream, dispatches `ToolUse` events either to `McpClient`
(connect tools) or to `handlePhoneSideTool` (meta tools like
`render_panel`, `monitor_threshold`, `fleet_overview`), and replays
`ToolUse`/`ToolResult` pairs into the next turn — so stateless
providers (Ollama, Gemini) work on session resume identically to
stateful ones.

## Onboarding Flow

```mermaid
flowchart LR
    Start(["First launch · Scry tab · empty state"])
    Ollama("Use Ollama · free, local
    Settings → Ollama base URL + model")
    Claude("Use Claude · recommended
    Settings → Anthropic API key")
    OpenAI("Use OpenAI
    Settings → OpenAI API key")
    Gemini("Use Gemini · free tier
    Settings → Google AI API key")
    Start ==> Ollama
    Start ==> Claude
    Start ==> OpenAI
    Start ==> Gemini
    classDef brand fill:#292826,stroke:#3A3835,stroke-width:1px,color:#E8E4D9;
    classDef accent fill:#1C1B19,stroke:#A3B86C,stroke-width:2px,color:#A3B86C;
    class Ollama,Claude,OpenAI,Gemini brand;
    class Start accent;
    linkStyle default stroke:#A3B86C,stroke-width:1.5px,color:#9C9A8D;
```

Provider and model are then chosen via the **top-bar chip** on the chat
screen — the chip is the single source of truth, so you can swap models
mid-conversation without bouncing through Settings. The Settings screen
only stores the credentials.

If no provider is configured, the chat screen shows a setup prompt
guiding the user to Settings.

## API Key Storage

All API keys stored in Android `EncryptedSharedPreferences`:
- AES-256 encryption
- Backed by Android Keystore
- Never logged, never transmitted except to the provider's API
- User can view/edit/delete at any time in Settings

## Future: Scry Cloud (V2)

A backend proxy that holds our own API keys:
- Users pay a Scry subscription instead of managing API keys
- Freemium model: X free queries/month, paid tier for unlimited
- Simplifies onboarding to zero-config
- Requires cloud infrastructure (deferred to V2)
