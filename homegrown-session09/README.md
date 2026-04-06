# Homegrown Session 09: Self-Hosted Infrastructure & RAG

This session covers setting up a local LLM on a Raspberry Pi, connecting it to a mesh network (Meshtastic) via MQTT, and implementing a RAG (Retrieval-Augmented Generation) pipeline for private document querying.

## Phase 1: Local LLM Infrastructure (Raspberry Pi & Ollama)

The foundation uses **Ollama** to run models locally on the Raspberry Pi 5.

### 1. Install Ollama
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### 2. Download Recommended Models
- **For 4GB RAM Pi:**
  ```bash
  ollama pull tinyllama
  ```
- **For 8GB RAM Pi:**
  ```bash
  ollama pull llama3.2:3b
  ```

### 3. Start & Verify
```bash
ollama serve &
ollama run tinyllama "Hello, world!"
```

---

## Phase 2: Mesh Network & MQTT Integration

Connect the local LLM to a Meshtastic radio mesh and a shared website via MQTT.

### 1. Hardware Setup
- Connect one Meshtastic device to the Pi via USB.
- Pair a second device to a phone via Bluetooth.

### 2. Channel Configuration (Indices 3-7)
- **3: `sysop`** (Admin/BBS)
- **4: `sheila`** (Conversational AI)
- **5: `webmistress`** (MQTT Website Control)
- **6: `lowviz`** (ASCII Art)
- **7: `mmmmmmorse`** (Morse Code)

### 3. Clone & Setup the Channels App
```bash
git clone https://github.com/chootka/channels.git
cd channels
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 4. Configure `.env`
```text
MQTT_BROKER=dweb2025.nohost.me
MQTT_PORT=1883
CHANNELS_FILE=channels_ollama.yaml
```

### 5. Run the Bridge
```bash
python main_ollama.py
```

---

## Phase 3: RAG Pipeline (Retrieval-Augmented Generation)

Enhance the LLM with your own private documents using ChromaDB.

### 1. Install ChromaDB
```bash
pip install chromadb
```

### 2. Index Your Documents
To store text files into the vector database:
```bash
python index_files.py ~/my_notes
```

### 3. Run RAG Queries
Ask questions that require context from your indexed files:
```bash
python rag.py
```

### 4. Full Knowledge Base Loop
A combined script for indexing and chatting:
```bash
python knowledge_base.py ~/my_notes
```

---

## Phase 4: Troubleshooting & Testing

### Serial Port Issues
If the Meshtastic device isn't found (e.g., `/dev/ttyUSB0`), add your user to the dialout group:
```bash
sudo usermod -a -G dialout $USER
```

### MQTT Manual Test
```bash
mosquitto_pub -h dweb2025.nohost.me -p 1883 -t 'test' -m 'hello'
```

### Webmistress Commands
Test the live website (`https://mqtt.dweb2025.nohost.me`) by sending these to channel 5:
- "make it blue"
- "rotate"
- "hide"

---

## Teaching Guide & Pedagogical Context

### 1. "Why are we doing this?" (The Core Objective)
Move students from being **consumers** of cloud-based AI to **architects** of private, self-hosted infrastructures.

- **Sovereignty & Privacy:** Demonstrate that AI can function without "phoning home." Running on a Raspberry Pi means owning both the data and the intelligence layer.
- **Resource Constraints:** Using "tiny" models (like `tinyllama`) teaches the trade-offs between model size, speed, and hardware requirements.
- **Grounding Truth (RAG):** Solve the "hallucination" problem by forcing the AI to answer based on specific, local evidence rather than general training data.

### 2. Key Concepts to Highlight
- **Local vs. Cloud:** 
  - *Cloud:* High cost, API keys, rate limits, data harvesting, requires internet.
  - *Local:* $0 cost, total privacy, works offline (Ollama), but slower and less "smart" than giant models.
- **The RAG Pipeline (Index → Retrieve → Generate):**
  - **Index:** Turning text into "embeddings" (mathematical vectors).
  - **Retrieve:** Using a vector database (ChromaDB) to find chunks of text mathematically similar to a question.
  - **Generate:** Injecting those chunks into the LLM's prompt as an "open book" reference.
- **Mesh Networking (Meshtastic):** Radio (LoRa) provides a decentralized communication layer independent of cell towers or Wi-Fi.

### 3. Discussion Questions for the Class
- **On Embeddings:** "If I search for 'wireless communication' and the document says 'radio waves,' will a keyword search find it? Will a vector search? Why?" (*Answer: Vector search matches meaning, not just letters.*)
- **On Privacy:** "If you index your private journals into this system, who else can see them? How does this change if you used ChatGPT instead?"
- **On Reliability:** "What happens to our AI agents if the building's internet goes down? What happens to the website control?" (*Answer: The AI and Radio keep working; only the MQTT/Website bridge fails.*)

### 4. Critical Demonstrations
- **The "Aha!" Moment:** Ask the LLM a question about the class syllabus *without* RAG (it will fail/guess), then ask *with* RAG (it will answer correctly).
- **The Physical Bridge:** Trace the flow: **Phone (Bluetooth) → Meshtastic Device (Radio) → Raspberry Pi (USB/Python) → Ollama (Local LLM).**

---

## Resources
- [Walkthrough Guide](https://github.com/chootka/homegrown-tools-self-hosted-infrastructures/blob/main/week7-9/walkthrough-guide.md)
- [Session 2 Guide](https://github.com/chootka/homegrown-tools-self-hosted-infrastructures/blob/main/week7-9/session2-guide.md)
- [Session 3 Guide](https://github.com/chootka/homegrown-tools-self-hosted-infrastructures/blob/main/week7-9/session3-guide.md)
