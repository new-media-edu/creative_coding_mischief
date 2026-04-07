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
    
    // Draw Source View (Left) - no zoom/pan
    fill(40);
    noStroke();
    rect(mappingAreaX, 0, viewW, height);
    if (selectedSurface != null) {
      selectedSurface.display(this, true, mappingAreaX, viewW, true);
    }
    
    fill(255, 100);
    textAlign(CENTER, TOP);
    text("SOURCE VIEW (CROPPING)", mappingAreaX + viewW/2, 10);
    
    // Draw Mapping View (Right) - with zoom/pan
    if (showMappingGuide) {
      drawGuideBackground(mappingAreaX + viewW, 0, viewW, height);
    } else {
      fill(20);
      noStroke();
      rect(mappingAreaX + viewW, 0, viewW, height);
    }
    
    clip(mappingAreaX + viewW, 0, viewW, height);
    pushMatrix();
    translate(mappingAreaX + viewW + canvasPanX, canvasPanY);
    scale(canvasZoom);
    for (int si = 0; si < surfaces.size(); si++) {
      guideIndex = si;
      surfaces.get(si).display(this, true, 0, viewW, false);
    }
    popMatrix();
    noClip();
    
    fill(255, 100);
    textAlign(CENTER, TOP);
    text("MAPPING VIEW (OUTPUT)", mappingAreaX + viewW + viewW/2, 10);
    
    stroke(0);
    line(mappingAreaX + viewW, 0, mappingAreaX + viewW, height);
  } else {
    // Full Mapping View - with zoom/pan
    if (showMappingGuide) {
      drawGuideBackground(mappingAreaX, 0, mappingAreaW, height);
    }
    
    clip(mappingAreaX, 0, mappingAreaW, height);
    pushMatrix();
    translate(mappingAreaX + canvasPanX, canvasPanY);
    scale(canvasZoom);
    for (int si = 0; si < surfaces.size(); si++) {
      guideIndex = si;
      surfaces.get(si).display(this, true, 0, mappingAreaW, false);
    }
    popMatrix();
    noClip();
    
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
  textSize(14);
  textAlign(LEFT, TOP);
  text("CONTROLS", UI_MARGIN, 12);
  
  float btnY = 38;
  float btnW = SIDEBAR_WIDTH - (UI_MARGIN * 2);
  float btnH = 26;
  float spacing = 5;
  
  textSize(11);
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
  btnY += btnH + spacing;
  drawButton(UI_MARGIN, btnY, btnW, btnH, "Mirror (M): " + mirrorLabels[outputMirror]);
  btnY += btnH + spacing;
  drawButton(UI_MARGIN, btnY, btnW, btnH, "Guide (G): " + (showMappingGuide ? "ON" : "OFF"));
  
  btnY += btnH + 12;
  stroke(100);
  line(UI_MARGIN, btnY, SIDEBAR_WIDTH - UI_MARGIN, btnY);
  
  btnY += 8;
  fill(180);
  textSize(10);
  textAlign(LEFT, TOP);
  text("Display: " + outputDisplay + "  Zoom: " + nf(canvasZoom * 100, 0, 0) + "%", UI_MARGIN, btnY);
  btnY += 16;
  text("Quads: " + surfaces.size(), UI_MARGIN, btnY);
  
  int selectedCount = 0;
  for (Surface s : surfaces) {
    for (boolean b : s.selectedCorners) if (b) selectedCount++;
  }
  if (selectedCount > 0) {
    text("  Sel. Vertices: " + selectedCount, UI_MARGIN + 60, btnY);
  }
  
  if (selectedSurface != null) {
    btnY += 20;
    fill(0, 255, 0);
    textSize(10);
    text("SELECTED:", UI_MARGIN, btnY);
    btnY += 14;
    fill(200);
    String path = selectedSurface.mediaPath;
    if (path.equals("")) path = "No media";
    else {
      File f = new File(path);
      path = f.getName();
    }
    text(path, UI_MARGIN, btnY, btnW, 40);
  }
  
  fill(120);
  textSize(9);
  textAlign(LEFT, BOTTOM);
  String help = "Scroll:Zoom  ALT+Drag:Pan  0:Reset\nSHIFT:Multi-select  D/DEL:Delete";
  text(help, UI_MARGIN, height - 8);
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

void drawGuideBackground(float x, float y, float w, float h) {
  noStroke();
  textureWrap(REPEAT);
  textureMode(IMAGE);
  beginShape(QUADS);
  texture(guideGridBg);
  vertex(x, y, 0, 0);
  vertex(x + w, y, w, 0);
  vertex(x + w, y + h, w, h);
  vertex(x, y + h, 0, h);
  endShape();
}
