/**
 * Projection App - Main Module
 * This file coordinates the state and execution of the Controller and Output windows.
 */

import processing.video.*;
import processing.serial.*;
import processing.sound.*;

// Global State
ArrayList<Surface> surfaces;
Surface selectedSurface = null;
LiveAV liveAV;

// UI/Interaction State
boolean isMarquee = false;
float marqueeX1, marqueeY1;
boolean isDraggingVertex = false;
boolean isDraggingShape = false;
boolean isDraggingSourceVertex = false;
boolean isDraggingSourceShape = false;
boolean showSourceView = false;

// Configuration Constants
int SIDEBAR_WIDTH = 220;
int UI_MARGIN = 20;
int outputDisplay = 2; // Default to display 2 (projector)

// Secondary Window
OutputWindow output;

// Diagnostics
int diagMovieEventCount = 0;

void settings() {
  size(1200, 700, P3D); 
}

void setup() {
  surface.setTitle("Projection Mapper - Controller");
  
  println("--- System Diagnostics ---");
  println("OS: " + System.getProperty("os.name") + " " + System.getProperty("os.version"));
  println("Java: " + System.getProperty("java.version"));
  println("GStreamer Path Prop: " + System.getProperty("gst.plugin.path"));
  
  // Linux GStreamer conflict resolution
  System.setProperty("gst.plugin.path", "/usr/lib/x86_64-linux-gnu/gstreamer-1.0");
  System.setProperty("gst.registry.fork", "false");
  
  // Aggressively disable plugins that cause SIGSEGV on Linux/NVIDIA/GStreamer 1.24
  // We disable: NVIDIA hardware codecs (nv*), VAAPI (vaapi*), and problematic libav elements
  String disableRanks = "souphttpsrc:0"
    + ",nvh264dec:0,nvh265dec:0,nvdec:0,nvenc:0,nvh264sldec:0,nvv4l2h264enc:0"
    + ",vaapidecode:0,vaapiencode:0,vaapipostproc:0"
    + ",avdec_h264:0,avdec_h265:0,avdec_mpeg4:0";
  System.setProperty("GST_PLUGIN_FEATURE_RANK", disableRanks);
  
  println("GST_PLUGIN_FEATURE_RANK set to: " + disableRanks);
  println("--------------------------");
  
  surfaces = new ArrayList<Surface>();
  
  // Initialize Live AV Manager
  liveAV = new LiveAV(this);
  
  // Load previous configuration
  loadConfig();
  if (surfaces.isEmpty()) {
    surfaces.add(new Surface(this));
  }
  
  // Spawn the secondary output window
  output = new OutputWindow();
  PApplet.runSketch(new String[] {"OutputWindow"}, output);
}

void draw() {
  background(25);
  
  // 0. Update Live AV data
  liveAV.update();
  
  synchronized(surfaces) {
    // 1. Sync video bridge frames (movieEvent fires read(); here we copy pixels to PImage)
    for (Surface s : surfaces) {
      s.updateVideoBridge();
    }
    
    // 2. Draw Controller UI and Mapping Area
    drawMainWorkspace();
  }
  
  // 3. Draw Overlays
  if (isMarquee) {
    drawMarquee();
  }
  
  // 4. Draw Sidebar
  drawSidebar();
}

// Draw the marquee selection box
void drawMarquee() {
  stroke(0, 255, 255, 150);
  fill(0, 255, 255, 30);
  rect(marqueeX1, marqueeY1, mouseX - marqueeX1, mouseY - marqueeY1);
}

// Called by the video library on a background thread when a new frame is ready.
void movieEvent(Movie m) {
  m.read();
  diagMovieEventCount++;
  if (diagMovieEventCount <= 5) {
    // Check pixels RIGHT here, before any loadPixels() call.
    // If these are non-zero, video.loadPixels() in updateVideoBridge is the bug.
    // If these are zero, the library is using a GL texture path and pixels[] is never populated.
    String p0 = (m.pixels != null && m.pixels.length > 0) ? hex(m.pixels[0]) : "null";
    String pm = (m.pixels != null && m.pixels.length > 1) ? hex(m.pixels[m.pixels.length/2]) : "null";
    println("[DIAG] movieEvent #" + diagMovieEventCount
      + "  w=" + m.width + "  h=" + m.height
      + "  pixel[0]=" + p0 + "  pixel[mid]=" + pm);
  }
}


