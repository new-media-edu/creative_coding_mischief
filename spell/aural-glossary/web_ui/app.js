// EventSource Client Connection
let eventSource = null;
let isStarted = false;

// DOM Elements
const systemStatus = document.getElementById('system-status');
const statusText = systemStatus ? systemStatus.querySelector('.status-text') || systemStatus : null;
const pulseIndicator = systemStatus ? systemStatus.querySelector('.pulse-indicator') : null;

const btnStart = document.getElementById('btn-start');
const btnStop = document.getElementById('btn-stop');
const inputLabels = document.getElementById('labels-input');

const transcriptionFeed = document.getElementById('transcription-feed');
const clapContainer = document.getElementById('clap-container');

// DSP Elements
const valRms = document.getElementById('val-rms');
const fillRms = document.getElementById('fill-rms');
const valCentroid = document.getElementById('val-centroid');
const fillCentroid = document.getElementById('fill-centroid');
const valTempo = document.getElementById('val-tempo');
const fillTempo = document.getElementById('fill-tempo');

// Teleprompter DOM Elements
const alignmentStatus = document.getElementById('alignment-status');
const valAccuracy = document.getElementById('val-accuracy');
const thresholdSlider = document.getElementById('threshold-slider');
const valThreshold = document.getElementById('val-threshold');
const btnResetScript = document.getElementById('btn-reset-script');
const btnToggleEdit = document.getElementById('btn-toggle-edit');
const scriptEditContainer = document.getElementById('script-edit-container');
const scriptTextarea = document.getElementById('script-textarea');
const btnSaveScript = document.getElementById('btn-save-script');
const btnCancelEdit = document.getElementById('btn-cancel-edit');
const teleprompterView = document.getElementById('teleprompter-view');
const deviationPanel = document.getElementById('deviation-panel');
const deviationTranscription = document.getElementById('deviation-transcription');

// Script State
let scriptWords = [];
let scriptIndex = 0;

// Initialize Connection
function connect() {
    console.log('Connecting to EventSource: /events');
    
    eventSource = new EventSource('/events');
    
    eventSource.onopen = () => {
        console.log('EventSource connected');
        updateStatus(true);
    };
    
    eventSource.onerror = (error) => {
        console.error('EventSource Error:', error);
        updateStatus(false);
    };
    
    eventSource.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            handleServerEvent(data);
        } catch (e) {
            console.error('Failed to parse EventSource message:', e);
        }
    };
}

function updateStatus(isOnline) {
    if (isOnline) {
        if (statusText) statusText.textContent = '[ONLINE]';
        if (pulseIndicator) pulseIndicator.className = 'pulse-indicator online';
    } else {
        if (statusText) statusText.textContent = '[OFFLINE]';
        if (pulseIndicator) pulseIndicator.className = 'pulse-indicator offline';
        setStartedState(false);
    }
}

function setStartedState(started) {
    isStarted = started;
    btnStart.disabled = started;
    btnStop.disabled = !started;
    inputLabels.disabled = started;
    
    if (started) {
        btnStart.textContent = 'SYSTEM RUNNING...';
    } else {
        btnStart.textContent = 'START SYSTEM';
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
    
    // Script reset/update
    if (packet.type === 'script_reset') {
        scriptTextarea.value = packet.script;
        thresholdSlider.value = packet.threshold;
        valThreshold.textContent = `${Math.round(packet.threshold * 100)}%`;
        renderScript(packet.script, packet.words, 0);
        
        // Reset status
        alignmentStatus.className = 'align-status-badge';
        alignmentStatus.querySelector('.align-status-text').textContent = 'IDLE';
        valAccuracy.textContent = '0%';
        deviationPanel.classList.add('hidden');
    }
    
    // Script alignment updates
    if (packet.type === 'alignment') {
        const accuracy = packet.accuracy;
        const newIndex = packet.script_index;
        const status = packet.status;
        
        // Update accuracy
        valAccuracy.textContent = `${Math.round(accuracy * 100)}%`;
        
        // Update status badge
        if (status === 'following') {
            alignmentStatus.className = 'align-status-badge following';
            alignmentStatus.querySelector('.align-status-text').textContent = 'FOLLOWING';
            deviationPanel.classList.add('hidden');
            
            // Highlight matching words
            updateWordHighlighting(newIndex);
        } else {
            alignmentStatus.className = 'align-status-badge deviating';
            alignmentStatus.querySelector('.align-status-text').textContent = 'DEVIATING';
            
            // Show deviation transcription
            deviationPanel.classList.remove('hidden');
            deviationTranscription.textContent = packet.transcription;
        }
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

// Update Live Story (no-op in minimal mode)
function updateStory(story) {
}

// Render script with layout preservation
function renderScript(script, words, currentIndex) {
    scriptWords = words || [];
    scriptIndex = currentIndex || 0;
    
    teleprompterView.innerHTML = '';
    
    if (scriptWords.length === 0) {
        teleprompterView.innerHTML = '<div class="feed-placeholder">No script loaded. Click "Edit Script" to paste one.</div>';
        return;
    }
    
    const rawTokens = script.split(/(\s+)/);
    let wordCounter = 0;
    
    rawTokens.forEach(token => {
        if (token.trim() === '') {
            const textNode = document.createTextNode(token);
            teleprompterView.appendChild(textNode);
        } else {
            const span = document.createElement('span');
            span.className = 'word-span';
            span.id = `word-${wordCounter}`;
            span.textContent = token;
            
            if (wordCounter < scriptIndex) {
                span.classList.add('word-spoken');
            } else if (wordCounter === scriptIndex) {
                span.classList.add('word-current');
            }
            
            teleprompterView.appendChild(span);
            wordCounter++;
        }
    });
}

function fetchScript() {
    fetch('/api/script')
        .then(res => res.json())
        .then(data => {
            scriptTextarea.value = data.script;
            thresholdSlider.value = data.threshold;
            valThreshold.textContent = `${Math.round(data.threshold * 100)}%`;
            renderScript(data.script, data.words, data.script_index);
        })
        .catch(err => console.error('Error fetching script:', err));
}

function updateWordHighlighting(newIndex) {
    scriptIndex = newIndex;
    for (let i = 0; i < scriptWords.length; ++i) {
        const span = document.getElementById(`word-${i}`);
        if (!span) continue;
        
        if (i < scriptIndex) {
            span.className = 'word-span word-spoken';
        } else if (i === scriptIndex) {
            span.className = 'word-span word-current';
        } else {
            span.className = 'word-span';
        }
    }
    
    const currentWordEl = document.getElementById(`word-${scriptIndex}`);
    if (currentWordEl) {
        currentWordEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
}

// Bind Button actions
btnStart.onclick = () => {
    const cmd = {
        llm: 'none',
        labels: inputLabels.value || null
    };
    
    fetch('/api/start', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(cmd)
    })
    .then(res => res.json())
    .then(data => {
        if (data.success) {
            setStartedState(true);
        } else {
            alert('Failed to start system.');
        }
    })
    .catch(err => {
        console.error('Error starting system:', err);
    });
};

btnStop.onclick = () => {
    fetch('/api/stop', {
        method: 'POST'
    })
    .then(res => res.json())
    .then(data => {
        setStartedState(false);
    })
    .catch(err => {
        console.error('Error stopping system:', err);
    });
};

// Bind Teleprompter Control Listeners
thresholdSlider.oninput = () => {
    const val = thresholdSlider.value;
    valThreshold.textContent = `${Math.round(val * 100)}%`;
    
    fetch('/api/set_threshold', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ threshold: parseFloat(val) })
    })
    .catch(err => console.error('Error setting threshold:', err));
};

btnResetScript.onclick = () => {
    fetch('/api/reset_script', {
        method: 'POST'
    })
    .catch(err => console.error('Error resetting script:', err));
};

btnToggleEdit.onclick = () => {
    scriptEditContainer.classList.toggle('hidden');
};

btnCancelEdit.onclick = () => {
    scriptEditContainer.classList.add('hidden');
};

btnSaveScript.onclick = () => {
    const scriptVal = scriptTextarea.value;
    fetch('/api/script', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ script: scriptVal })
    })
    .then(res => res.json())
    .then(data => {
        if (data.success) {
            scriptEditContainer.classList.add('hidden');
        }
    })
    .catch(err => console.error('Error saving script:', err));
};

// Start connection and fetch script on load once page finishes loading
window.addEventListener('load', () => {
    connect();
    fetchScript();
});
