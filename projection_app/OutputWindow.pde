/**
 * OutputWindow Module
 * The clean, secondary window designed for the projector.
 */

public class OutputWindow extends PApplet {
  
  public void settings() {
    // Note: display 1 is typically the primary monitor, 2 is the projector.
    fullScreen(P3D, outputDisplay);
    pixelDensity(displayDensity());
  }
  
  public void setup() { 
    background(0); 
    // Optimization: avoid standard loop overhead if needed, but 
    // standard setup is fine for this use case.
  }
  
  public void draw() {
    background(0);
    
    // Apply output mirror/flip transform
    pushMatrix();
    switch (outputMirror) {
      case 1: // Mirror Horizontal
        translate(width, 0);
        scale(-1, 1);
        break;
      case 2: // Mirror Vertical
        translate(0, height);
        scale(1, -1);
        break;
      case 3: // Mirror H+V
        translate(width, height);
        scale(-1, -1);
        break;
    }
    
    // Force modified=true on every video frame before drawing.
    // Use synchronized to avoid conflicts with main sketch modifications
    synchronized(surfaces) {
      for (int si = 0; si < surfaces.size(); si++) {
        if ((surfaces.get(si).isVideo || surfaces.get(si).isLive) && surfaces.get(si).videoFrame != null) {
          surfaces.get(si).videoFrame.setModified(true);
        }
      }
      
      for (int si = 0; si < surfaces.size(); si++) {
        guideIndex = si;
        surfaces.get(si).display(this, false, 0, width, false);
      }
    }
    popMatrix();
  }
}
