// WebSocket Client Connection
let ws = null;
let reconnectInterval = 1000;
let isStarted = false;

// DOM Elements
const systemStatus = document.getElementById('system-status');
const statusText = systemStatus.querySelector('.status-text');
const pulseIndicator = systemStatus.querySelector('.pulse-indicator');

const btnStart = document.getElementById('btn-start');
const btnStop = document.getElementById('btn-stop');
const selectLlm = document.getElementById('llm-select');
const inputLabels = document.getElementById('labels-input');

const storyDisplay = document.getElementById('story-display');
const transcriptionFeed = document.getElementById('transcription-feed');
const clapContainer = document.getElementById('clap-container');

// DSP Elements
const valRms = document.getElementById('val-rms');
const fillRms = document.getElementById('fill-rms');
const valCentroid = document.getElementById('val-centroid');
const fillCentroid = document.getElementById('fill-centroid');
const valTempo = document.getElementById('val-tempo');
const fillTempo = document.getElementById('fill-tempo');

// Initialize Connection
function connect() {
    const wsUrl = `ws://${window.location.hostname}:8081`;
    console.log(`Connecting to WebSocket server: ${wsUrl}`);
    
    ws = new WebSocket(wsUrl);
    
    ws.onopen = () => {
        console.log('WebSocket connected');
        updateStatus(true);
        reconnectInterval = 1000; // reset reconnect timer
    };
    
    ws.onclose = () => {
        console.log('WebSocket disconnected');
        updateStatus(false);
        // Try reconnecting
        setTimeout(connect, reconnectInterval);
        reconnectInterval = Math.min(reconnectInterval * 2, 10000); // exponential backoff
    };
    
    ws.onerror = (error) => {
        console.error('WebSocket Error:', error);
    };
    
    ws.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            handleServerEvent(data);
        } catch (e) {
            console.error('Failed to parse websocket message:', e);
        }
    };
}

function updateStatus(isOnline) {
    if (isOnline) {
        statusText.textContent = 'ONLINE';
        pulseIndicator.className = 'pulse-indicator online';
    } else {
        statusText.textContent = 'OFFLINE';
        pulseIndicator.className = 'pulse-indicator offline';
        setStartedState(false);
    }
}

function setStartedState(started) {
    isStarted = started;
    btnStart.disabled = started;
    btnStop.disabled = !started;
    selectLlm.disabled = started;
    inputLabels.disabled = started;
    
    if (started) {
        btnStart.textContent = 'System Running...';
    } else {
        btnStart.textContent = 'Start System';
    }
}

// Handle incoming JSON event packets
function handleServerEvent(packet) {
    // If packet tells us system status
    if (packet.type === 'status') {
        if (packet.status === 'started') {
            setStartedState(true);
        } else if (packet.status === 'stopped') {
            setStartedState(false);
        }
    }
    
    // Engine A: Transcription
    if (packet.type === 'transcription') {
        appendTranscription(packet.text, packet.confidence, packet.start_ms, packet.end_ms);
    }
    
    // Engine B: DSP & CLAP Classification
    if (packet.type === 'analysis') {
        updateDsp(packet.rms, packet.centroid, packet.tempo);
        updateClapBars(packet.labels);
    }
    
    // Brain: Synesthetic Story
    if (packet.type === 'story') {
        updateStory(packet.story);
    }
}

// Render dynamic CLAP bars
let labelElements = {}; // cache of bar elements to prevent re-creation
function updateClapBars(labels) {
    if (!labels || Object.keys(labels).length === 0) return;
    
    // Check if we need to clear the placeholder
    const placeholder = clapContainer.querySelector('.feed-placeholder');
    if (placeholder) {
        clapContainer.innerHTML = '';
    }
    
    // Sort labels by probability
    const sortedLabels = Object.entries(labels).sort((a, b) => b[1] - a[1]);
    
    // We only display the top 5 sounds to keep layout clean
    const topLabels = sortedLabels.slice(0, 5);
    
    // Clear and rebuild container to keep them sorted in display
    clapContainer.innerHTML = '';
    
    topLabels.forEach(([name, prob]) => {
        const item = document.createElement('div');
        item.className = 'clap-item';
        
        const labelRow = document.createElement('div');
        labelRow.className = 'clap-label-row';
        
        const labelName = document.createElement('span');
        labelName.className = 'clap-label-name';
        labelName.textContent = name;
        
        const labelVal = document.createElement('span');
        labelVal.className = 'clap-label-val';
        labelVal.textContent = `${(prob * 100).toFixed(1)}%`;
        
        labelRow.appendChild(labelName);
        labelRow.appendChild(labelVal);
        
        const progress = document.createElement('div');
        progress.className = 'progress-bar';
        
        const fill = document.createElement('div');
        fill.className = 'progress-fill violet-fill';
        fill.style.width = `${prob * 100}%`;
        
        progress.appendChild(fill);
        item.appendChild(labelRow);
        item.appendChild(progress);
        
        clapContainer.appendChild(item);
    });
}

// Update DSP meters
function updateDsp(rms, centroid, tempo) {
    // RMS (Loudness)
    valRms.textContent = rms.toFixed(4);
    // Multiply by 400 to amplify small values for visual display
    const rmsPercent = Math.min(rms * 400, 100);
    fillRms.style.width = `${rmsPercent}%`;
    
    // Centroid (Brightness) - assume centroid ranges up to 8000Hz
    valCentroid.textContent = `${Math.round(centroid)} Hz`;
    const centroidPercent = Math.min((centroid / 8000) * 100, 100);
    fillCentroid.style.width = `${centroidPercent}%`;
    
    // Tempo - assume tempo ranges up to 180BPM
    valTempo.textContent = `${Math.round(tempo)} BPM`;
    const tempoPercent = Math.min((tempo / 180) * 100, 100);
    fillTempo.style.width = `${tempoPercent}%`;
}

// Update Scrolling Transcription Feed
function appendTranscription(text, confidence, startMs, endMs) {
    const placeholder = transcriptionFeed.querySelector('.feed-placeholder');
    if (placeholder) {
        transcriptionFeed.innerHTML = '';
    }
    
    const item = document.createElement('div');
    item.className = 'dialogue-item';
    
    const textSpan = document.createElement('span');
    textSpan.className = 'dialogue-text';
    textSpan.textContent = text;
    
    const metaSpan = document.createElement('div');
    metaSpan.className = 'dialogue-meta';
    
    const timeSpan = document.createElement('span');
    const t0 = (startMs / 1000).toFixed(1);
    const t1 = (endMs / 1000).toFixed(1);
    timeSpan.textContent = `[${t0}s --> ${t1}s]`;
    
    const confSpan = document.createElement('span');
    confSpan.textContent = `Confidence: ${(confidence * 100).toFixed(0)}%`;
    
    metaSpan.appendChild(timeSpan);
    metaSpan.appendChild(confSpan);
    item.appendChild(textSpan);
    item.appendChild(metaSpan);
    
    transcriptionFeed.appendChild(item);
    
    // Auto scroll to bottom
    transcriptionFeed.scrollTop = transcriptionFeed.scrollHeight;
}

// Update Live Story
function updateStory(story) {
    // Add smooth fade out/in effect
    storyDisplay.style.opacity = '0';
    setTimeout(() => {
        storyDisplay.textContent = story;
        storyDisplay.style.opacity = '1';
    }, 200);
}

// Bind Button actions
btnStart.onclick = () => {
    if (ws && ws.readyState === WebSocket.OPEN) {
        const cmd = {
            cmd: 'start',
            llm: selectLlm.value,
            labels: inputLabels.value || null
        };
        ws.send(json.dumps ? json.dumps(cmd) : JSON.stringify(cmd));
        setStartedState(true);
    }
};

btnStop.onclick = () => {
    if (ws && ws.readyState === WebSocket.OPEN) {
        const cmd = { cmd: 'stop' };
        ws.send(json.dumps ? json.dumps(cmd) : JSON.stringify(cmd));
        setStartedState(false);
    }
};

// Start WS connection on load
connect();
