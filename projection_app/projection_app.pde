/**
 * Projection App - Main Module
 * This file coordinates the state and execution of the Controller and Output windows.
 */

import processing.video.*;

// Global State
ArrayList<Surface> surfaces;
Surface selectedSurface = null;

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
  
  // Linux GStreamer conflict resolution
  System.setProperty("gst.plugin.path", "/usr/lib/x86_64-linux-gnu/gstreamer-1.0");
  System.setProperty("GST_PLUGIN_FEATURE_RANK", "souphttpsrc:0");
  
  surfaces = new ArrayList<Surface>();
  
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
  
  // 1. Sync video bridge frames (movieEvent fires read(); here we copy pixels to PImage)
  for (Surface s : surfaces) {
    s.updateVideoBridge();
  }
  
  // 2. Draw Controller UI and Mapping Area
  drawMainWorkspace();
  
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
  if (diagMovieEventCount <= 3) {
    println("[DIAG] movieEvent fired #" + diagMovieEventCount
      + "  video.width=" + m.width + "  video.height=" + m.height
      + "  time=" + m.time());
  }
}


