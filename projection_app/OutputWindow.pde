/**
 * OutputWindow Module
 * The clean, secondary window designed for the projector.
 */

public class OutputWindow extends PApplet {
  
  public void settings() {
    // Note: display 1 is typically the primary monitor, 2 is the projector.
    fullScreen(P3D, outputDisplay); 
  }
  
  public void setup() { 
    background(0); 
    // Optimization: avoid standard loop overhead if needed, but 
    // standard setup is fine for this use case.
  }
  
  public void draw() {
    background(0);
    
    // Force modified=true on every video frame before drawing.
    // The main sketch's renderer clears this flag after uploading to its own GL
    // context. Without this, the output window's GL context sees modified=false
    // and never re-uploads beyond the first frame.
    for (Surface s : surfaces) {
      if (s.isVideo && s.videoFrame != null) {
        s.videoFrame.setModified(true);
      }
    }
    
    for (Surface s : surfaces) {
      s.display(this, false, 0, width, false);
    }
  }
}
