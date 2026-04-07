# Homegrown Session 09: Self-Hosted Infrastructure & RAG

This session covers setting up a local LLM on a Raspberry Pi and implementing a RAG (Retrieval-Augmented Generation) pipeline for private document querying. The stretch goal is integrating RAG within the Meshtastic/Channels mesh network context.

**Primary goal:** Get RAG working with Ollama on the Pis.  
**Stretch goal:** Get RAG working within the context of the Meshtastic Channels app.

---

## Phase 1: Local LLM Infrastructure (Raspberry Pi & Ollama)

> If you were here last session and already have Ollama running, skip to Phase 3.

The foundation uses **Ollama** to run models locally on the Raspberry Pi 5.

### 1. SSH into Your Pi
```bash
ssh your-username@your-pi-address
```

Check prerequisites:
```bash
python3 --version   # Should show Python 3.x — if not: sudo apt install python3
pip3 --version      # If not: sudo apt install python3-pip
git --version       # If not: sudo apt install git
python3 -m venv --help  # If not: sudo apt install python3-venv
```

### 2. Install Ollama
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### 3. Download a Model
- **For 4GB RAM Pi:**
  ```bash
  ollama pull tinyllama
  ```
- **For 8GB RAM Pi (better quality):**
  ```bash
  ollama pull llama3.2:3b
  ```

### 4. Start & Verify
```bash
ollama serve &
ollama run tinyllama "What is a mesh network? Answer in one sentence."
```
It will take a few seconds — that's normal on a Pi. You should see a response.

---

## Phase 2: Mesh Network & MQTT Integration (Channels App)

> If you were here last session and already have the Channels app running, skip to Phase 3.

Connect the local LLM to a Meshtastic radio mesh and a shared website via MQTT using Sarah's [Channels](https://github.com/chootka/channels) app.

**Note on naming:** Meshtastic devices have a maximum of 8 channels. Sarah's software is also called "Channels" — confusing, but her app is a Python bridge that imports the Meshtastic libraries to route radio messages to local AI agents.

### 1. Hardware Setup
- Connect one Meshtastic device to the Pi via USB
- Pair a second device to a phone via Bluetooth

Check the device is detected:
```bash
ls /dev/ttyUSB*
# If nothing: ls /dev/ttyACM*
```

### 2. Configure Meshtastic Channels (Indices 3-7)

Open the Meshtastic app on your phone, connect to your device via Bluetooth, and add these channels:

| Index | Name | What it does |
|-------|------|-------------|
| 3 | `sysop` | Admin agent — BBS-style operator |
| 4 | `sheila` | Conversational agent — sarcastic helper |
| 5 | `webmistress` | Controls the shared website via MQTT |
| 6 | `lowviz` | ASCII art agent — responds in patterns only |
| 7 | `mmmmmmorse` | Morse code translator |

Leave PSK as default (`AQ==`) — just make sure both devices use the same key. You also need the same channels on the device plugged into the Pi (connect via Bluetooth temporarily to configure, then switch back to USB).

### 3. Clone & Setup the Channels App
```bash
cd ~
git clone https://github.com/chootka/channels.git
cd channels
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 4. Configure `.env`
```bash
cd ~/channels
nano .env
```
```text
MQTT_BROKER=dweb2025.nohost.me
MQTT_PORT=1883
CHANNELS_FILE=channels_ollama.yaml
RUN_LOCAL_LLM=true
```

> `RUN_LOCAL_LLM=true` tells the app to use Ollama instead of a remote API. No API key needed.

### 5. Run the Bridge
```bash
python main_ollama.py
```
You should see:
```
[router] Loaded 5 channels: 3=sysop, 4=sheila, 5=webmistress, 6=lowviz, 7=mmmmmmorse
[main] Connecting to Meshtastic device...
[main] Using LOCAL Ollama — no internet or API key needed.
[main] Listening for messages. Ctrl+C to quit.
```

### 6. Test It
From your phone's Meshtastic app:
- **Channel 4 (sheila):** Send "hello" — wait 5-15 seconds for a response
- **Channel 5 (webmistress):** Send "make it blue" — check `https://mqtt.dweb2025.nohost.me`
- Other webmistress commands: `rotate`, `stripes`, `hide`, `show`, `reset`

---

## Phase 3: RAG Pipeline (Retrieval-Augmented Generation)

This is the main event. RAG makes an LLM answer questions about **your** data — documents it was never trained on.

### What is RAG?

Three steps:
1. **Index** — split your documents into chunks, convert to vectors (embeddings), store in a database
2. **Retrieve** — when you ask a question, find the most relevant chunks by mathematical similarity
3. **Generate** — feed those chunks + your question to the LLM

**Without RAG:** "When is the week 5 assignment due?" → LLM guesses or says it doesn't know.  
**With RAG:** Same question → system finds the syllabus chunk → LLM answers correctly from your documents.

### Key Concepts

- **Embeddings:** Converting text into a list of numbers (a vector) that captures its meaning. Similar texts produce similar vectors.
  ```
  "cats like fish"     → [0.2, -0.1, 0.8, ...]
  "dogs enjoy meat"    → [0.3, -0.1, 0.7, ...]  ← similar meaning, similar numbers
  "quantum physics"    → [-0.5, 0.9, -0.2, ...]  ← different meaning, different numbers
  ```
- **Vector Database (ChromaDB):** Searches by *meaning*, not keywords. "How do computers talk to each other" finds "TCP/IP Fundamentals" even though no words match.
- **Why it matters:** Everything runs locally. Your documents never leave your Pi. $0 cost, no API keys, no rate limits.

### Part 1: Embeddings + Vector Database (~60 min)

#### 1. Set up a RAG project

This runs in its own virtualenv, separate from the Channels app:

```bash
mkdir ~/rag-lab
cd ~/rag-lab
python3 -m venv venv
source venv/bin/activate
pip install chromadb requests
```

#### 2. Create `index_docs.py`

This stores sample documents in ChromaDB and queries by similarity:

```python
import chromadb

client = chromadb.Client()
collection = client.create_collection("my_notes")

# Add some documents
collection.add(
    documents=[
        "TCP uses a three-way handshake: SYN, SYN-ACK, ACK",
        "UDP is connectionless and does not guarantee delivery",
        "DNS translates domain names to IP addresses",
        "MQTT is a lightweight messaging protocol for IoT devices",
        "LoRa is a long-range, low-power wireless protocol used by Meshtastic",
    ],
    ids=["tcp", "udp", "dns", "mqtt", "lora"],
)

# Query — find documents similar to this question
query = "how do devices communicate wirelessly?"
results = collection.query(query_texts=[query], n_results=2)

print(f"Query: {query}\n")
print("Most relevant documents:")
for doc in results["documents"][0]:
    print(f"  → {doc}")
```

Run it:
```bash
python index_docs.py
```

#### 3. Try different queries

Edit the `query` variable and re-run. Try:
- `"what protocol translates names to addresses?"`
- `"low power long range communication"`
- `"how do connections get established?"`

Notice: it finds relevant documents even when you don't use the exact same words. That's the power of vector search.

### Part 2: Full RAG Pipeline (~60 min)

#### 4. Create `rag.py`

This combines retrieval + Ollama generation:

```python
import chromadb
import requests

# --- Set up vector database with some sample docs ---
db = chromadb.Client()
collection = db.create_collection("notes")

collection.add(
    documents=[
        "The assignment for week 5 is due Friday October 18th",
        "TCP uses congestion control to avoid overwhelming the network",
        "Meshtastic devices communicate over LoRa at 868 MHz in Europe",
        "Ollama runs LLMs locally on your machine with no internet required",
        "A vector database stores embeddings and allows similarity search",
        "RAG stands for Retrieval-Augmented Generation",
    ],
    ids=["1", "2", "3", "4", "5", "6"],
)

print("RAG demo — ask questions about the indexed documents.")
print("Type 'quit' to exit.\n")

while True:
    question = input("You: ")
    if question.lower() == "quit":
        break

    # Step 1: Retrieve relevant chunks
    results = collection.query(query_texts=[question], n_results=2)
    chunks = results["documents"][0]

    print(f"\n  [Retrieved chunks:]")
    for chunk in chunks:
        print(f"    → {chunk}")
    print()

    # Step 2: Build prompt with context
    context = "\n".join(chunks)
    prompt = f"""Based on the following context, answer the question. If the context doesn't contain the answer, say so.

Context:
{context}

Question: {question}

Answer concisely:"""

    # Step 3: Generate answer with local LLM
    response = requests.post("http://localhost:11434/api/generate", json={
        "model": "tinyllama",
        "prompt": prompt,
        "stream": False,
    })

    print(f"LLM: {response.json()['response']}\n")
```

Run it:
```bash
python rag.py
```

#### 5. The "Aha!" Demo

Ask: `"When is the week 5 assignment due?"`
- **With RAG** (this script) → it finds the syllabus chunk and gives the correct date
- **Without RAG** (just `ollama run tinyllama "When is the week 5 assignment due?"`) → it doesn't know

This is the whole point. The LLM is grounded in your data.

#### 6. Index your own documents

Create `index_files.py` — this reads `.txt` files from any folder and makes them searchable:

```python
"""Index text files from a folder into ChromaDB and query them."""

import os
import sys
import chromadb

if len(sys.argv) < 2:
    print("Usage: python index_files.py <folder_path>")
    print("Example: python index_files.py ~/my_notes")
    sys.exit(1)

folder = os.path.expanduser(sys.argv[1])

if not os.path.isdir(folder):
    print(f"Error: {folder} is not a directory")
    sys.exit(1)

# --- Read all .txt files ---
documents = []
doc_ids = []

for filename in sorted(os.listdir(folder)):
    if not filename.endswith(".txt"):
        continue

    filepath = os.path.join(folder, filename)
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read().strip()

    if not text:
        continue

    # Split into chunks at paragraph breaks
    chunks = text.split("\n\n")
    for i, chunk in enumerate(chunks):
        chunk = chunk.strip()
        if len(chunk) < 20:
            continue
        doc_id = f"{filename}_{i}"
        documents.append(chunk)
        doc_ids.append(doc_id)

print(f"Found {len(documents)} chunks from {folder}\n")

if not documents:
    print("No .txt files with content found.")
    sys.exit(1)

# --- Index into ChromaDB ---
client = chromadb.Client()
collection = client.create_collection("my_files")
collection.add(documents=documents, ids=doc_ids)

print(f"Indexed {len(documents)} chunks. Ready to query.\n")
print("Type a question to search your documents. Type 'quit' to exit.\n")

while True:
    query = input("Search: ")
    if query.lower() == "quit":
        break

    results = collection.query(query_texts=[query], n_results=3)

    print()
    for i, doc in enumerate(results["documents"][0]):
        source = results["ids"][0][i]
        print(f"  [{source}]")
        print(f"  {doc[:200]}{'...' if len(doc) > 200 else ''}")
        print()
```

Try it:
```bash
mkdir ~/my_notes
# Put some .txt files in there (lecture notes, anything)
python index_files.py ~/my_notes
```

### Part 3: Build Your Own Knowledge Base (~60 min)

#### 7. Create `knowledge_base.py`

The full pipeline in one script — indexes your documents and lets you ask questions in a loop:

```python
"""Personal knowledge base — indexes your documents and answers questions using RAG."""

import os
import sys
import chromadb
import requests

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "tinyllama"  # Change to "llama3.2:3b" if you have 8GB RAM

if len(sys.argv) < 2:
    print("Usage: python knowledge_base.py <folder_path>")
    print("Example: python knowledge_base.py ~/my_notes")
    sys.exit(1)

folder = os.path.expanduser(sys.argv[1])

if not os.path.isdir(folder):
    print(f"Error: {folder} is not a directory")
    sys.exit(1)

# --- Step 1: Read and chunk documents ---
documents = []
doc_ids = []

for filename in sorted(os.listdir(folder)):
    if not filename.endswith(".txt"):
        continue

    filepath = os.path.join(folder, filename)
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        text = f.read().strip()

    if not text:
        continue

    chunks = text.split("\n\n")
    for i, chunk in enumerate(chunks):
        chunk = chunk.strip()
        if len(chunk) < 20:
            continue
        documents.append(chunk)
        doc_ids.append(f"{filename}_{i}")

if not documents:
    print("No .txt files with content found.")
    sys.exit(1)

# --- Step 2: Index into ChromaDB ---
print(f"Indexing {len(documents)} chunks from {folder}...")
client = chromadb.Client()
collection = client.create_collection("knowledge_base")
collection.add(documents=documents, ids=doc_ids)
print(f"Done. Ready to answer questions.\n")
print("Ask questions about your documents. Type 'quit' to exit.\n")

# --- Step 3: Query loop ---
while True:
    question = input("You: ")
    if question.lower() == "quit":
        break

    # Retrieve relevant chunks
    results = collection.query(query_texts=[question], n_results=3)
    chunks = results["documents"][0]

    # Show what was retrieved
    print(f"\n  [Found {len(chunks)} relevant chunks]")
    for i, chunk in enumerate(chunks):
        source = results["ids"][0][i]
        preview = chunk[:80].replace("\n", " ")
        print(f"    {source}: {preview}...")
    print()

    # Build the prompt
    context = "\n---\n".join(chunks)
    prompt = f"""You are a helpful assistant. Answer the question based on the provided context.
If the context doesn't contain enough information, say so. Be concise.

Context:
{context}

Question: {question}

Answer:"""

    # Generate answer
    try:
        response = requests.post(OLLAMA_URL, json={
            "model": MODEL,
            "prompt": prompt,
            "stream": False,
        })
        answer = response.json()["response"]
        print(f"Answer: {answer}\n")
    except requests.ConnectionError:
        print("Error: Can't connect to Ollama. Is it running? (ollama serve)\n")
```

Run it:
```bash
python knowledge_base.py ~/my_notes
```

#### 8. Experiment
- Index different kinds of documents
- Tweak `n_results` (how many chunks to retrieve)
- If you have 8GB Pi, change MODEL to `"llama3.2:3b"` for smarter answers
- Edit the prompt template

### Starter Code Shortcut

All these scripts also exist in the course repo if students prefer to clone instead of type:
```bash
cd ~
git clone https://github.com/chootka/homegrown-tools-self-hosted-infrastructures.git
cd homegrown-tools-self-hosted-infrastructures/week7-9/starter-code/rag
pip install -r requirements.txt
python rag.py
```

> **Important:** Make sure Ollama is running on each Pi before starting any RAG scripts. If not: `ollama serve &`

---

## Phase 4: Stretch Goal — RAG + Meshtastic Channels

If we get through the RAG pipeline with time to spare, the next step is connecting RAG into the Channels mesh network — so people can query a knowledge base over radio.

This would involve modifying the Channels app to add a RAG-enabled agent that:
1. Receives a radio message on a dedicated channel
2. Retrieves relevant chunks from an indexed document set
3. Generates an answer via Ollama
4. Sends the answer back over radio

The Channels app already supports custom agents — check `channels_ollama.yaml` for how agents are defined, and `agents/base_ollama.py` for the Ollama API call pattern.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Permission denied` on serial port | `sudo usermod -a -G dialout $USER` then log out/in |
| Ollama not running | `ollama serve &` |
| Ollama is very slow | Normal on Pi — 5-15 seconds with tinyllama |
| No serial device found | Check cable (must be data, not charge-only), try different USB port, `ls /dev/ttyUSB* /dev/ttyACM*` |
| Agent gives weird long responses | Tinyllama is small — make system prompts shorter and more explicit |
| Website not changing | Check broker: `mosquitto_pub -h dweb2025.nohost.me -p 1883 -t 'test' -m 'hello'` |
| Multiple agents responding to same message | Check `.env` — each student needs a different `ACTIVE_CHANNELS` value |
| Heltec v4 not detected | Uses `/dev/ttyACM0` not `ttyUSB0`. May need firmware reflash |
| `meshtastic` command not found | `cd ~/channels && source venv/bin/activate` |
| Can't connect to Ollama from RAG script | Make sure you're in the `rag-lab` venv, and Ollama is running (`ollama serve &`) |

---

## Quick Restart Guide

When coming back to the Pi later:
```bash
ssh your-username@your-pi-address

# 1. Check Ollama is running
ollama run tinyllama "test"
# If "connection refused": ollama serve &

# 2. For RAG work:
cd ~/rag-lab
source venv/bin/activate

# 3. For Channels (if running mesh agents):
cd ~/channels
source venv/bin/activate
python main_ollama.py
```

---

## Key Concepts to Highlight

- **Local vs. Cloud:**
  - *Cloud:* API keys, rate limits, data harvesting, requires internet, costs money
  - *Local:* $0 cost, total privacy, works offline (Ollama), but slower and less "smart" than giant models
- **The RAG Pipeline (Index → Retrieve → Generate):**
  - **Index:** Turning text into "embeddings" (mathematical vectors)
  - **Retrieve:** Using a vector database (ChromaDB) to find chunks of text mathematically similar to a question
  - **Generate:** Injecting those chunks into the LLM's prompt as an "open book" reference
- **Mesh Networking (Meshtastic):** Radio (LoRa) provides a decentralized communication layer independent of cell towers or Wi-Fi

### Discussion Questions
- "If I search for 'wireless communication' and the document says 'radio waves,' will a keyword search find it? Will a vector search? Why?"
- "If you index your private journals into this system, who else can see them? How does this change if you used ChatGPT instead?"
- "What happens to our AI agents if the building's internet goes down?" *(Answer: The AI and Radio keep working; only the MQTT/Website bridge fails.)*

---

## Resources
- [Channels App (Sarah's repo)](https://github.com/chootka/channels)
- [Course Repo](https://github.com/chootka/homegrown-tools-self-hosted-infrastructures)
- [Walkthrough Guide](https://github.com/chootka/homegrown-tools-self-hosted-infrastructures/blob/main/week7-9/walkthrough-guide.md)
- [Session 2 Guide (RAG details)](https://github.com/chootka/homegrown-tools-self-hosted-infrastructures/blob/main/week7-9/session2-guide.md)
- [Session 3 Guide](https://github.com/chootka/homegrown-tools-self-hosted-infrastructures/blob/main/week7-9/session3-guide.md)
- [Channels Code Walkthrough](https://github.com/chootka/homegrown-tools-self-hosted-infrastructures/blob/main/week7-9/channels-code-walkthrough.md)
- [AI Glossary](https://github.com/chootka/homegrown-tools-self-hosted-infrastructures/blob/main/week7-9/glossary.md)
- Website: https://mqtt.dweb2025.nohost.me
