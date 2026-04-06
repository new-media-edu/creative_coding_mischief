/**
 * Interaction Module
 * Handles all mouse and keyboard events.
 */

void mousePressed() {
  if (mouseX < SIDEBAR_WIDTH) {
    handleSidebarClick();
    return;
  }
  
  int mappingAreaX = SIDEBAR_WIDTH;
  int mappingAreaW = width - SIDEBAR_WIDTH;
  
  if (showSourceView) {
    int viewW = mappingAreaW / 2;
    if (mouseX > mappingAreaX && mouseX < mappingAreaX + viewW) {
      if (selectedSurface != null) {
        int idx = selectedSurface.getSourceCornerAt(mouseX, mouseY, mappingAreaX, viewW, this);
        if (idx != -1) {
          selectedSurface.clearSourceSelection();
          selectedSurface.selectedSourceCorners[idx] = true;
          isDraggingSourceVertex = true;
          return;
        } else if (selectedSurface.isInsideSource(mouseX, mouseY, mappingAreaX, viewW, this)) {
          isDraggingSourceShape = true;
          return;
        }
      }
    }
    mappingAreaX += viewW;
    mappingAreaW = viewW;
  }
  
  boolean hitVertex = false;
  boolean hitEdge = false;
  
  // 1. Check Vertex Hits (Priority)
  for (Surface s : surfaces) {
    int idx = s.getCornerAt(mouseX, mouseY, mappingAreaX);
    if (idx != -1) {
      hitVertex = true;
      if (keyPressed && keyCode == SHIFT) {
        s.selectedCorners[idx] = !s.selectedCorners[idx]; // Toggle
        if (s.selectedCorners[idx]) s.isSelected = true;
      } else if (!s.selectedCorners[idx]) {
        clearAllSelections();
        s.selectedCorners[idx] = true;
        s.isSelected = true;
        selectedSurface = s;
      }
      isDraggingVertex = true;
      break;
    }
  }
  
  // 2. Check Edge Hits
  if (!hitVertex) {
    for (Surface s : surfaces) {
      int edgeIdx = s.getEdgeAt(mouseX, mouseY, mappingAreaX);
      if (edgeIdx != -1) {
        hitEdge = true;
        if (!(keyPressed && keyCode == SHIFT)) clearAllSelections();
        s.selectedCorners[edgeIdx] = true;
        s.selectedCorners[(edgeIdx + 1) % 4] = true;
        s.isSelected = true;
        selectedSurface = s;
        isDraggingVertex = true;
        break;
      }
    }
  }
  
  // 3. Check Shape Hits
  if (!hitVertex && !hitEdge) {
    for (Surface s : surfaces) {
      if (s.isInside(mouseX, mouseY, mappingAreaX)) {
        if (!(keyPressed && keyCode == SHIFT) && !s.isSelected) clearAllSelections();
        s.isSelected = true;
        selectedSurface = s;
        isDraggingShape = true;
        return;
      }
    }
  }
  
  // 4. Marquee Selection
  if (!hitVertex && !hitEdge && !isDraggingShape) {
    if (!(keyPressed && keyCode == SHIFT)) clearAllSelections();
    isMarquee = true;
    marqueeX1 = mouseX;
    marqueeY1 = mouseY;
  }
}

void mouseDragged() {
  float dx = mouseX - pmouseX;
  float dy = mouseY - pmouseY;
  
  if (isDraggingSourceVertex || isDraggingSourceShape) {
    int viewW = (width - SIDEBAR_WIDTH) / 2;
    PImage tex = selectedSurface.isVideo ? selectedSurface.videoFrame : selectedSurface.img;
    if (tex != null) {
      float aspect = (float)tex.width / tex.height;
      float drawW = viewW - 40;
      float drawH = drawW / aspect;
      if (drawH > height - 40) {
        drawH = height - 40;
        drawW = drawH * aspect;
      }
      if (isDraggingSourceVertex) selectedSurface.moveSelectedSourceCorners(dx / drawW, dy / drawH);
      else selectedSurface.moveSource(dx / drawW, dy / drawH);
    }
  } else if (isDraggingVertex) {
    for (Surface s : surfaces) {
      s.moveSelectedCorners(dx, dy);
    }
  } else if (isDraggingShape) {
    if (selectedSurface != null) selectedSurface.move(dx, dy);
  }
}

void mouseReleased() {
  if (isMarquee) {
    int mappingAreaX = SIDEBAR_WIDTH;
    if (showSourceView) mappingAreaX += (width - SIDEBAR_WIDTH) / 2;
    for (Surface s : surfaces) {
      s.selectCornersInBox(marqueeX1, marqueeY1, mouseX, mouseY, mappingAreaX);
      if (anyCornerSelected(s)) s.isSelected = true;
    }
  }
  isMarquee = false;
  isDraggingVertex = false;
  isDraggingShape = false;
  isDraggingSourceVertex = false;
  isDraggingSourceShape = false;
}

void keyPressed() {
  if (key == 'a') addQuad();
  else if (key == 'l') loadMediaAction();
  else if (key == 'v') toggleSourceView();
  else if (key == 'k') toggleLiveAction();
  else if (key == 's') saveConfig();
  else if (key == 'd' || keyCode == BACKSPACE || keyCode == DELETE) deleteAction();
  else if (key == 'i' || key == 'I') {
    println("\n====== DIAGNOSTIC DUMP (frame " + frameCount + ") ======");
    println("movieEvent fires so far: " + diagMovieEventCount);
    for (int i = 0; i < surfaces.size(); i++) {
      surfaces.get(i).printDiag(i);
    }
    println("========================================\n");
  }
}

boolean anyCornerSelected(Surface s) {
  for (boolean b : s.selectedCorners) if (b) return true;
  return false;
}

void clearAllSelections() {
  selectedSurface = null;
  for (Surface s : surfaces) s.clearSelection();
}

void handleSidebarClick() {
  float btnW = SIDEBAR_WIDTH - (UI_MARGIN * 2);
  float btnH = 32;
  float spacing = 10;
  float startY = 60;
  
  if (mouseX > UI_MARGIN && mouseX < UI_MARGIN + btnW) {
    if (mouseY > startY && mouseY < startY + btnH) addQuad();
    else if (mouseY > startY + (btnH + spacing) && mouseY < startY + (btnH + spacing) + btnH) loadMediaAction();
    else if (mouseY > startY + (btnH + spacing) * 2 && mouseY < startY + (btnH + spacing) * 2 + btnH) toggleSourceView();
    else if (mouseY > startY + (btnH + spacing) * 3 && mouseY < startY + (btnH + spacing) * 3 + btnH) toggleLiveAction();
    else if (mouseY > startY + (btnH + spacing) * 4 && mouseY < startY + (btnH + spacing) * 4 + btnH) deleteAction();
    else if (mouseY > startY + (btnH + spacing) * 5 && mouseY < startY + (btnH + spacing) * 5 + btnH) saveConfig();
  }
}
