/**
 * Interface Module
 * Handles all UI drawing, sidebar layout, and workspace rendering.
 */

void drawMainWorkspace() {
  int mappingAreaX = SIDEBAR_WIDTH;
  int mappingAreaW = width - SIDEBAR_WIDTH;
  
  hint(DISABLE_DEPTH_TEST);
  
  if (showSourceView) {
    int viewW = mappingAreaW / 2;
    
    // Draw Source View (Left)
    fill(40);
    noStroke();
    rect(mappingAreaX, 0, viewW, height);
    if (selectedSurface != null) {
      selectedSurface.display(this, true, mappingAreaX, viewW, true);
    }
    
    fill(255, 100);
    textAlign(CENTER, TOP);
    text("SOURCE VIEW (CROPPING)", mappingAreaX + viewW/2, 10);
    
    // Draw Output View (Right)
    fill(20);
    rect(mappingAreaX + viewW, 0, viewW, height);
    for (Surface s : surfaces) {
      s.display(this, true, mappingAreaX + viewW, viewW, false);
    }
    
    fill(255, 100);
    textAlign(CENTER, TOP);
    text("MAPPING VIEW (OUTPUT)", mappingAreaX + viewW + viewW/2, 10);
    
    stroke(0);
    line(mappingAreaX + viewW, 0, mappingAreaX + viewW, height);
  } else {
    // Full Mapping View
    for (Surface s : surfaces) {
      s.display(this, true, mappingAreaX, mappingAreaW, false);
    }
    fill(255, 100);
    textAlign(CENTER, TOP);
    text("MAPPING VIEW", mappingAreaX + mappingAreaW/2, 10);
  }
}

void drawSidebar() {
  fill(45);
  noStroke();
  rect(0, 0, SIDEBAR_WIDTH, height);
  
  fill(255);
  textSize(16);
  textAlign(LEFT, TOP);
  text("CONTROLS", UI_MARGIN, UI_MARGIN);
  
  float btnY = 60;
  float btnW = SIDEBAR_WIDTH - (UI_MARGIN * 2);
  float btnH = 32;
  float spacing = 10;
  
  textSize(12);
  drawButton(UI_MARGIN, btnY, btnW, btnH, "Add Quad (A)");
  btnY += btnH + spacing;
  drawButton(UI_MARGIN, btnY, btnW, btnH, "Load Media (L)");
  btnY += btnH + spacing;
  drawButton(UI_MARGIN, btnY, btnW, btnH, "Source View (V)");
  btnY += btnH + spacing;
  drawButton(UI_MARGIN, btnY, btnW, btnH, "Live AV (K)");
  btnY += btnH + spacing;
  drawButton(UI_MARGIN, btnY, btnW, btnH, "Delete Quad (D)");
  btnY += btnH + spacing;
  drawButton(UI_MARGIN, btnY, btnW, btnH, "Save Config (S)");
  
  btnY += btnH + 40;
  stroke(100);
  line(UI_MARGIN, btnY, SIDEBAR_WIDTH - UI_MARGIN, btnY);
  
  btnY += 20;
  fill(180);
  textAlign(LEFT, TOP);
  text("Output Display: " + outputDisplay, UI_MARGIN, btnY);
  btnY += 25;
  text("Total Quads: " + surfaces.size(), UI_MARGIN, btnY);
  
  int selectedCount = 0;
  for (Surface s : surfaces) {
    for (boolean b : s.selectedCorners) if (b) selectedCount++;
  }
  text("Selected Vertices: " + selectedCount, UI_MARGIN, btnY + 25);
  
  if (selectedSurface != null) {
    btnY += 80;
    fill(0, 255, 0);
    text("SELECTED QUAD:", UI_MARGIN, btnY);
    btnY += 20;
    fill(200);
    textSize(10);
    String path = selectedSurface.mediaPath;
    if (path.equals("")) path = "No media loaded";
    else {
      File f = new File(path);
      path = f.getName();
    }
    text(path, UI_MARGIN, btnY, btnW, 60);
  }
  
  fill(120);
  textSize(10);
  textAlign(LEFT, BOTTOM);
  String help = "V: Toggle Source View\nDRAG: Move vertex/crop\nDRAG INSIDE: Move shape\nSHIFT: Multi-select\nBACKSPACE/D: Delete";
  text(help, UI_MARGIN, height - UI_MARGIN);
}

void drawButton(float x, float y, float w, float h, String label) {
  boolean hover = mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h;
  fill(hover ? 75 : 55);
  stroke(90);
  rect(x, y, w, h, 4);
  fill(255);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2);
}
