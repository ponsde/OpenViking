<div align="center">

<picture>
  <img alt="OpenViking" src="docs/images/banner.jpg" width="100%" height="auto">
</picture>

### OpenViking: The Context Database for AI Agents

English / [中文](README_CN.md)

<a href="https://www.openviking.ai">Website</a> · <a href="https://github.com/volcengine/OpenViking">GitHub</a> · <a href="https://github.com/volcengine/OpenViking/issues">Issues</a> · <a href="https://www.openviking.ai/docs">Docs</a>

[![][release-shield]][release-link]
[![][github-stars-shield]][github-stars-link]
[![][github-issues-shield]][github-issues-shield-link]
[![][github-contributors-shield]][github-contributors-link]
[![][license-shield]][license-shield-link]
[![][last-commit-shield]][last-commit-shield-link]

👋 Join our Community

📱 <a href="./docs/en/about/01-about-us.md#lark-group">Lark Group</a> · <a href="./docs/en/about/01-about-us.md#wechat-group">WeChat</a> · <a href="https://discord.com/invite/eHvx8E9XF3">Discord</a> · <a href="https://x.com/openvikingai">X</a>

</div>

---

## Overview

### Challenges in Agent Development

In the AI era, data is abundant, but high-quality context is hard to come by. When building AI Agents, developers often face these challenges:

- **Fragmented Context**: Memories are in code, resources are in vector databases, and skills are scattered, making them difficult to manage uniformly.
- **Surging Context Demand**: An Agent's long-running tasks produce context at every execution. Simple truncation or compression leads to information loss.
- **Poor Retrieval Effectiveness**: Traditional RAG uses flat storage, lacking a global view and making it difficult to understand the full context of information.
- **Unobservable Context**: The implicit retrieval chain of traditional RAG is like a black box, making it hard to debug when errors occur.
- **Limited Memory Iteration**: Current memory is just a record of user interactions, lacking Agent-related task memory.

### The OpenViking Solution

**OpenViking** is an open-source **Context Database** designed specifically for AI Agents.

We aim to define a minimalist context interaction paradigm for Agents, allowing developers to completely say goodbye to the hassle of context management. OpenViking abandons the fragmented vector storage model of traditional RAG and innovatively adopts a **"file system paradigm"** to unify the structured organization of memories, resources, and skills needed by Agents.

With OpenViking, developers can build an Agent's brain just like managing local files:

- **Filesystem Management Paradigm** → **Solves Fragmentation**: Unified context management of memories, resources, and skills based on a filesystem paradigm.
- **Tiered Context Loading** → **Reduces Token Consumption**: L0/L1/L2 three-tier structure, loaded on demand, significantly saving costs.
- **Directory Recursive Retrieval** → **Improves Retrieval Effect**: Supports native filesystem retrieval methods, combining directory positioning with semantic search to achieve recursive and precise context acquisition.
- **Visualized Retrieval Trajectory** → **Observable Context**: Supports visualization of directory retrieval trajectories, allowing users to clearly observe the root cause of issues and guide retrieval logic optimization.
- **Automatic Session Management** → **Context Self-Iteration**: Automatically compresses content, resource references, tool calls, etc., in conversations, extracting long-term memory, making the Agent smarter with use.

---

## Installation

**Quick Start (5 minutes):**

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install OpenViking server
uv tool install openviking

# Install ov CLI for skills
curl -fsSL https://raw.githubusercontent.com/volcengine/OpenViking/main/crates/ov_cli/install.sh | bash

# Configure and start
mkdir -p ~/.openviking
# Create ~/.openviking/ov.conf with your API keys
# See INSTALL.md for full config template

export OPENVIKING_CONFIG_DIR=~/.openviking
openviking-server
```

📖 **[Full Installation Guide →](./INSTALL.md)**

For advanced configuration (cloud deployment, Docker, multiple model providers), see **[INSTALL_ADVANCED.md](./INSTALL_ADVANCED.md)**.

---

## Model Preparation

OpenViking requires the following model capabilities:
- **VLM Model**: For image and content understanding
- **Embedding Model**: For vectorization and semantic retrieval

### Supported VLM Providers

| Provider | Model | Get API Key |
|----------|-------|-------------|
| `volcengine` | doubao | [Volcengine Console](https://console.volcengine.com/ark) |
| `openai` | gpt | [OpenAI Platform](https://platform.openai.com) |
| `anthropic` | claude | [Anthropic Console](https://console.anthropic.com) |
| `deepseek` | deepseek | [DeepSeek Platform](https://platform.deepseek.com) |
| `gemini` | gemini | [Google AI Studio](https://aistudio.google.com) |
| `moonshot` | kimi | [Moonshot Platform](https://platform.moonshot.cn) |
| `zhipu` | glm | [Zhipu Open Platform](https://open.bigmodel.cn) |
| `dashscope` | qwen | [DashScope Console](https://dashscope.console.aliyun.com) |
| `minimax` | minimax | [MiniMax Platform](https://platform.minimax.io) |
| `openrouter` | (any model) | [OpenRouter](https://openrouter.ai) |
| `vllm` | (local model) | — |

> 💡 **Tip**: OpenViking uses a **Provider Registry** for unified model access. The system automatically detects the provider based on model name keywords, so you can switch between providers seamlessly.

### Provider-Specific Notes

<details>
<summary><b>Volcengine (Doubao)</b></summary>

Volcengine supports both model names and endpoint IDs. Using model names is recommended for simplicity:

```json
{
  "vlm": {
    "provider": "volcengine",
    "model": "doubao-seed-1-6-240615",
    "api_key": "your-api-key",
    "api_base" : "https://ark.cn-beijing.volces.com/api/v3"
  }
}
```

You can also use endpoint IDs (found in [Volcengine ARK Console](https://console.volcengine.com/ark)):

```json
{
  "vlm": {
    "provider": "volcengine",
    "model": "ep-20241220174930-xxxxx",
    "api_key": "your-api-key",
    "api_base" : "https://ark.cn-beijing.volces.com/api/v3"
  }
}
```

</details>

<details>
<summary><b>Zhipu AI (智谱)</b></summary>

If you're on Zhipu's coding plan, use the coding API endpoint:

```json
{
  "vlm": {
    "provider": "zhipu",
    "model": "glm-4-plus",
    "api_key": "your-api-key",
    "api_base": "https://open.bigmodel.cn/api/coding/paas/v4"
  }
}
```

</details>

<details>
<summary><b>MiniMax (中国大陆)</b></summary>

For MiniMax's mainland China platform (minimaxi.com), specify the API base:

```json
{
  "vlm": {
    "provider": "minimax",
    "model": "abab6.5s-chat",
    "api_key": "your-api-key",
    "api_base": "https://api.minimaxi.com/v1"
  }
}
```

</details>

<details>
<summary><b>Local Models (vLLM)</b></summary>

Run OpenViking with your own local models using vLLM:

```bash
# Start vLLM server
vllm serve meta-llama/Llama-3.1-8B-Instruct --port 8000
```

```json
{
  "vlm": {
    "provider": "vllm",
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "api_key": "dummy",
    "api_base": "http://localhost:8000/v1"
  }
}
```

</details>

---

## Quick Example

```python
import openviking as ov

# Initialize OpenViking client with data directory
client = ov.SyncOpenViking(path="./data")

try:
    # Initialize the client
    client.initialize()

    # Add resource (supports URL, file, or directory)
    add_result = client.add_resource(
        path="https://raw.githubusercontent.com/volcengine/OpenViking/refs/heads/main/README.md"
    )
    root_uri = add_result['root_uri']

    # Explore the resource tree structure
    ls_result = client.ls(root_uri)
    print(f"Directory structure:\n{ls_result}\n")

    # Use glob to find markdown files
    glob_result = client.glob(pattern="**/*.md", uri=root_uri)
    if glob_result['matches']:
        content = client.read(glob_result['matches'][0])
        print(f"Content preview: {content[:200]}...\n")

    # Wait for semantic processing to complete
    print("Wait for semantic processing...")
    client.wait_processed()

    # Get abstract and overview of the resource
    abstract = client.abstract(root_uri)
    overview = client.overview(root_uri)
    print(f"Abstract:\n{abstract}\n\nOverview:\n{overview}\n")

    # Perform semantic search
    results = client.find("what is openviking", target_uri=root_uri)
    print("Search results:")
    for r in results.resources:
        print(f"  {r.uri} (score: {r.score:.4f})")

    # Close the client
    client.close()

except Exception as e:
    print(f"Error: {e}")
```

---

## Skills

Skills enable agents to use OpenViking through simple keywords:

| Keyword | Skill | What It Does |
|---------|-------|--------------|
| `ovm` | adding-memory | Extracts and stores insights from conversation |
| `ovr` | adding-resource | Imports files/URLs into OpenViking |
| `ovs` | searching-context | Searches stored memories and resources |

See [INSTALL.md](./INSTALL.md) for skill installation instructions.

---

## Server Deployment

For production environments, we recommend running OpenViking as a standalone HTTP service:

```bash
# Start server
export OPENVIKING_CONFIG_DIR=~/.openviking
openviking-server

# Or run in background
nohup openviking-server > ~/.openviking/server.log 2>&1 &
```

🚀 For cloud deployment (ECS, Docker, Kubernetes), see **[INSTALL_ADVANCED.md](./INSTALL_ADVANCED.md)**.

---

## Core Concepts

### 1. Filesystem Management Paradigm → Solves Fragmentation

We no longer view context as flat text slices but unify them into an abstract virtual filesystem. Whether it's memories, resources, or capabilities, they are mapped to virtual directories under the `viking://` protocol, each with a unique URI.

```
viking://
├── resources/  # Resources: project docs, repos, web pages, etc.
│   └── my_project/
│       ├── docs/
│       └── src/
├── user/       # User: personal preferences, habits, etc.
│   └── memories/
│       └── preferences/
└── agent/      # Agent: skills, instructions, task memories, etc.
    ├── skills/
    └── memories/
```

Learn more: [Viking URI](./docs/en/concepts/04-viking-uri.md) | [Context Types](./docs/en/concepts/02-context-types.md)

### 2. Tiered Context Loading → Reduces Token Consumption

OpenViking automatically processes context into three levels upon writing:

- **L0 (Abstract)**: A one-sentence summary for quick retrieval and identification (~100 tokens)
- **L1 (Overview)**: Contains core information and usage scenarios for Agent decision-making (~2k tokens)
- **L2 (Details)**: The full original data, for deep reading when absolutely necessary

Learn more: [Context Layers](./docs/en/concepts/03-context-layers.md)

### 3. Directory Recursive Retrieval → Improves Retrieval Effect

Single vector retrieval struggles with complex query intents. OpenViking uses an innovative Directory Recursive Retrieval Strategy:

1. **Intent Analysis**: Generate multiple retrieval conditions
2. **Initial Positioning**: Use vector retrieval to locate high-score directories
3. **Refined Exploration**: Perform secondary retrieval within directories
4. **Recursive Drill-down**: Repeat for subdirectories
5. **Result Aggregation**: Return the most relevant context

Learn more: [Retrieval Mechanism](./docs/en/concepts/07-retrieval.md)

### 4. Visualized Retrieval Trajectory → Observable Context

The retrieval trajectory is fully preserved, allowing users to clearly observe the root cause of issues and guide retrieval logic optimization.

### 5. Automatic Session Management → Context Self-Iteration

At the end of each session, the system asynchronously analyzes task execution results and automatically updates User and Agent memory directories, making the Agent "smarter with use."

Learn more: [Session Management](./docs/en/concepts/08-session.md)

---

## Project Architecture

```
OpenViking/
├── openviking/      # Core source code
│   ├── core/        # Client, engine, filesystem
│   ├── models/      # VLM and Embedding model integration
│   ├── parse/       # Resource parsing
│   ├── retrieve/    # Semantic and directory retrieval
│   ├── storage/     # Vector DB, filesystem queue
│   └── session/     # History, memory extraction
├── docs/            # Documentation
├── examples/        # Usage examples
├── tests/           # Test cases
└── src/             # C++ extensions
```

---

## Community & Team

### About Us

OpenViking is an open-source context database initiated and maintained by the ByteDance Volcengine Viking Team.

The Viking team focuses on unstructured information processing and intelligent retrieval:

- **2019**: VikingDB vector database supported large-scale use across all ByteDance businesses
- **2023**: VikingDB sold on Volcengine public cloud
- **2024**: Launched developer product matrix: VikingDB, Viking KnowledgeBase, Viking MemoryBase
- **2025**: Created upper-layer application products like AI Search and Vaka Knowledge Assistant
- **Oct 2025**: Open-sourced [MineContext](https://github.com/volcengine/MineContext)
- **Jan 2026**: Open-sourced OpenViking

### Join the Community

- 📱 **Lark Group**: [Join here](./docs/en/about/01-about-us.md#lark-group)
- 💬 **WeChat**: [Join here](./docs/en/about/01-about-us.md#wechat-group)
- 🎮 **Discord**: [Join here](https://discord.com/invite/eHvx8E9XF3)
- 🐦 **X (Twitter)**: [Follow us](https://x.com/openvikingai)

---

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](./LICENSE) file for details.

<!-- Links -->
[release-shield]: https://img.shields.io/github/v/release/volcengine/OpenViking?style=flat-square
[release-link]: https://github.com/volcengine/OpenViking/releases
[github-stars-shield]: https://img.shields.io/github/stars/volcengine/OpenViking?style=flat-square
[github-stars-link]: https://github.com/volcengine/OpenViking/stargazers
[github-issues-shield]: https://img.shields.io/github/issues/volcengine/OpenViking?style=flat-square
[github-issues-shield-link]: https://github.com/volcengine/OpenViking/issues
[github-contributors-shield]: https://img.shields.io/github/contributors/volcengine/OpenViking?style=flat-square
[github-contributors-link]: https://github.com/volcengine/OpenViking/graphs/contributors
[license-shield]: https://img.shields.io/github/license/volcengine/OpenViking?style=flat-square
[license-shield-link]: https://github.com/volcengine/OpenViking/blob/main/LICENSE
[last-commit-shield]: https://img.shields.io/github/last-commit/volcengine/OpenViking?style=flat-square
[last-commit-shield-link]: https://github.com/volcengine/OpenViking/commits/main
