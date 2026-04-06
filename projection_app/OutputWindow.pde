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
    
    // Draw all surfaces using their bridge frames or standard textures.
    // We pass 'this' as the parent PApplet to ensure correct context rendering.
    for (Surface s : surfaces) {
      s.display(this, false, 0, width, false);
    }
  }
}
