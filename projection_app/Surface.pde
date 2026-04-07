/**
 * Surface Module
 * Handles individual mapping quads, texture interpolation, and cross-window video bridging.
 */

class Surface {
  PVector[] corners;
  PVector[] sourceCorners;
  boolean[] selectedCorners;
  boolean[] selectedSourceCorners;
  boolean isSelected = false;
  
  PImage img;
  Movie video;
  PGraphics bridgeG;  // Offscreen PGraphics for GPU->CPU pixel readback
  PImage videoFrame;  // CPU-side bridge image shared with the output window
  String mediaPath = "";
  String pendingMediaPath = "";
  boolean isVideo = false;
  boolean isLive = false;
  boolean isPlayground = false;
  
  int gridRes = 20; 
  
  Surface(PApplet parent) {
    corners = new PVector[4];
    sourceCorners = new PVector[4];
    selectedCorners = new boolean[4];
    selectedSourceCorners = new boolean[4];
    
    corners[0] = new PVector(150, 100);
    corners[1] = new PVector(350, 100);
    corners[2] = new PVector(350, 300);
    corners[3] = new PVector(150, 300);
    
    sourceCorners[0] = new PVector(0, 0);
    sourceCorners[1] = new PVector(1, 0);
    sourceCorners[2] = new PVector(1, 1);
    sourceCorners[3] = new PVector(0, 1);
  }
  
  Surface(PApplet parent, JSONObject json) {
    this(parent);
    JSONArray jsonCorners = json.getJSONArray("corners");
    for (int i = 0; i < 4; i++) {
      JSONObject cp = jsonCorners.getJSONObject(i);
      corners[i] = new PVector(cp.getFloat("x"), cp.getFloat("y"));
    }
    JSONArray jsonSrc = json.getJSONArray("sourceCorners");
    if (jsonSrc != null) {
      for (int i = 0; i < 4; i++) {
        JSONObject cp = jsonSrc.getJSONObject(i);
        sourceCorners[i] = new PVector(cp.getFloat("x"), cp.getFloat("y"));
      }
    }
    mediaPath = json.getString("mediaPath", "");
    if (!mediaPath.equals("")) loadMedia(parent, mediaPath);
    
    isLive = json.getBoolean("isLive", false);
    if (isLive) setLive(true);
    
    isPlayground = json.getBoolean("isPlayground", false);
    if (isPlayground) setPlayground(true);
  }
  
  void setLive(boolean live) {
    if (live && !isLive) {
      unloadMedia();
      isLive = true;
      isPlayground = false;
      liveAV.trigger(true);
    } else if (!live && isLive) {
      isLive = false;
      liveAV.trigger(false);
    }
  }
  
  void setPlayground(boolean pg) {
    if (pg && !isPlayground) {
      unloadMedia();
      isPlayground = true;
      isLive = false;
      playground.trigger(true);
    } else if (!pg && isPlayground) {
      isPlayground = false;
      playground.trigger(false);
    }
  }
  
  void unloadMedia() {
    if (isLive) {
      liveAV.trigger(false);
      isLive = false;
    }
    if (isPlayground) {
      playground.trigger(false);
      isPlayground = false;
    }
    
    // Set isVideo to false FIRST to stop other threads from accessing 'video'
    isVideo = false;
    
    if (video != null) {
      try {
        video.stop();
        // Small delay to let GStreamer thread stop before dispose
        delay(20);
        video.dispose();
      } catch (Exception e) {}
      video = null;
    }
    
    if (bridgeG != null) {
      bridgeG.dispose();
      bridgeG = null;
    }
    videoFrame = null;
    img = null;
    mediaPath = "";
  }

  void loadMedia(PApplet parent, String path) {
    this.pendingMediaPath = path;
  }

  private void performLoadMedia(PApplet parent, String path) {
    // Stop and release any previously loaded video before replacing it
    if (video != null) {
      video.stop();
      video.dispose();
      video = null;
    }
    if (bridgeG != null) {
      bridgeG.dispose();
      bridgeG = null;
    }
    videoFrame = null;

    this.mediaPath = path;
    this.isLive = false;
    String lowerPath = path.toLowerCase();
    if (lowerPath.endsWith(".mp4") || lowerPath.endsWith(".mov") || lowerPath.endsWith(".avi")) {
      try {
        println("[DEBUG] [Surface] GStreamer Load Start: " + path);
        video = new Movie(parent, path);
        println("[DEBUG] [Surface] GStreamer Load Success: " + path);
        video.loop();
        isVideo = true;
        img = null;
      } catch (Exception e) {
        println("Error loading video: " + e.getMessage());
      }
    } else {
      img = parent.loadImage(path);
      isVideo = false;
    }
  }

  /**
   * GPU->CPU bridge: the video library uploads frames directly to a GL texture
   * and never populates pixels[]. We draw the Movie into an offscreen P2D
   * PGraphics (same GL context as the primary sketch), then call loadPixels()
   * to do a glReadPixels readback into CPU memory. The resulting videoFrame
   * PImage carries real pixel data that can be uploaded in the output window's
   * separate GL context.
   */
  void updateVideoBridge() {
    // 1. Process thread-safe loading on the main animation thread
    if (!pendingMediaPath.equals("")) {
      performLoadMedia(projection_app.this, pendingMediaPath);
      pendingMediaPath = "";
      // Small safety delay after loading to let GStreamer settle
      delay(50);
    }
    
    if (isLive) {
      // Create or resize the offscreen readback surface
      if (bridgeG == null || bridgeG.width != liveAV.canvas.width || bridgeG.height != liveAV.canvas.height) {
        if (bridgeG != null) bridgeG.dispose();
        bridgeG = createGraphics(liveAV.canvas.width, liveAV.canvas.height, P2D);
      }
      bridgeG.beginDraw();
      bridgeG.image(liveAV.canvas, 0, 0);
      bridgeG.endDraw();
    } else if (isPlayground) {
      // Create or resize the offscreen readback surface for playground
      if (bridgeG == null || bridgeG.width != playground.canvas.width || bridgeG.height != playground.canvas.height) {
        if (bridgeG != null) bridgeG.dispose();
        bridgeG = createGraphics(playground.canvas.width, playground.canvas.height, P2D);
      }
      bridgeG.beginDraw();
      bridgeG.image(playground.canvas, 0, 0);
      bridgeG.endDraw();
    } else {
      if (!isVideo || video == null || video.width == 0 || video.height == 0) return;

      // Downsampling logic for high-res video (like 4K) to prevent GL/CPU bottlenecks
      int targetW = video.width;
      int targetH = video.height;
      if (video.width > 1280) {
        float scale = 1280.0 / video.width;
        targetW = 1280;
        targetH = (int)(video.height * scale);
      }

      // Create or resize the offscreen readback surface
      if (bridgeG == null || bridgeG.width != targetW || bridgeG.height != targetH) {
        if (bridgeG != null) bridgeG.dispose();
        bridgeG = createGraphics(targetW, targetH, P2D);
      }

      // Blit the Movie's GL texture into the PGraphics framebuffer (auto-resizes)
      bridgeG.beginDraw();
      bridgeG.image(video, 0, 0, targetW, targetH);
      bridgeG.endDraw();
    }

    // Readback from the framebuffer to CPU pixels[]
    bridgeG.loadPixels();

    // Use pixelWidth/pixelHeight to account for Retina/HiDPI scaling
    int pw = bridgeG.pixelWidth;
    int ph = bridgeG.pixelHeight;

    // Copy into the plain PImage bridge used by the output window
    if (videoFrame == null || videoFrame.width != pw || videoFrame.height != ph) {
      videoFrame = createImage(pw, ph, RGB);
    }
    videoFrame.loadPixels();
    System.arraycopy(bridgeG.pixels, 0, videoFrame.pixels, 0, bridgeG.pixels.length);
    videoFrame.updatePixels();
  }

  void display(PApplet p, boolean isController, int xOffset, int viewWidth, boolean isSourceView) {
    PImage tex;
    if (isVideo || isLive || isPlayground) {
      if (videoFrame != null) {
        tex = videoFrame;
      } else if (isController) {
        // Fallback only allowed in the controller window (same GL context)
        if (isLive) tex = liveAV.canvas;
        else if (isPlayground) tex = playground.canvas;
        else tex = video;
      } else {
        // Output window must wait for the bridge to be populated
        tex = null;
      }
    } else {
      tex = img;
    }
    
    p.pushMatrix();
    p.translate(xOffset, 0);
    
    if (isSourceView) {
      drawSourceView(p, tex, viewWidth);
    } else {
      drawMappingView(p, tex, isController);
    }
    p.popMatrix();
  }

  private void drawSourceView(PApplet p, PImage tex, int viewWidth) {
    if (tex == null) return;
    float aspect = (float)tex.width / tex.height;
    float drawW = viewWidth - 40;
    float drawH = drawW / aspect;
    if (drawH > p.height - 40) {
      drawH = p.height - 40;
      drawW = drawH * aspect;
    }
    float dx = (viewWidth - drawW) / 2;
    float dy = (p.height - drawH) / 2;
    
    p.image(tex, dx, dy, drawW, drawH);
    
    if (isSelected) {
      p.stroke(255, 255, 0, 150);
      p.fill(255, 255, 0, 40);
      p.beginShape();
      for (int i = 0; i < 4; i++) p.vertex(dx + sourceCorners[i].x * drawW, dy + sourceCorners[i].y * drawH);
      p.endShape(CLOSE);
      
      for (int i = 0; i < 4; i++) {
        p.fill(selectedSourceCorners[i] ? p.color(255, 0, 0) : p.color(255, 255, 0));
        p.noStroke();
        p.ellipse(dx + sourceCorners[i].x * drawW, dy + sourceCorners[i].y * drawH, 10, 10);
      }
    }
  }

  private void drawMappingView(PApplet p, PImage tex, boolean isController) {
    PImage activeTex = tex;
    PVector[] activeSrc = sourceCorners;
    
    if (showMappingGuide) {
      activeTex = guideTextures[guideIndex % guideTextures.length];
      activeSrc = new PVector[] {
        new PVector(0, 0), new PVector(1, 0),
        new PVector(1, 1), new PVector(0, 1)
      };
    }
    
    if (activeTex != null) {
      p.noStroke();
      p.beginShape(QUADS);
      p.texture(activeTex);
      p.textureMode(NORMAL);
      for (int y = 0; y < gridRes; y++) {
        for (int x = 0; x < gridRes; x++) {
          float u1 = (float)x / gridRes; float v1 = (float)y / gridRes;
          float u2 = (float)(x+1) / gridRes; float v2 = (float)(y+1) / gridRes;
          PVector p1 = getBilinearPoint(u1, v1, corners);
          PVector p2 = getBilinearPoint(u2, v1, corners);
          PVector p3 = getBilinearPoint(u2, v2, corners);
          PVector p4 = getBilinearPoint(u1, v2, corners);
          PVector t1 = getBilinearPoint(u1, v1, activeSrc);
          PVector t2 = getBilinearPoint(u2, v1, activeSrc);
          PVector t3 = getBilinearPoint(u2, v2, activeSrc);
          PVector t4 = getBilinearPoint(u1, v2, activeSrc);
          p.vertex(p1.x, p1.y, t1.x, t1.y);
          p.vertex(p2.x, p2.y, t2.x, t2.y);
          p.vertex(p3.x, p3.y, t3.x, t3.y);
          p.vertex(p4.x, p4.y, t4.x, t4.y);
        }
      }
      p.endShape();
    } else {
      p.stroke(255, 100);
      if (isSelected && isController) p.fill(0, 255, 0, 40);
      else p.noFill();
      p.beginShape();
      for (PVector c : corners) p.vertex(c.x, c.y);
      p.endShape(CLOSE);
    }
    
    if (isController) {
      if (isSelected) {
        p.stroke(0, 255, 0, 150); p.strokeWeight(2); p.noFill();
        p.beginShape();
        for (PVector c : corners) p.vertex(c.x, c.y);
        p.endShape(CLOSE);
        p.strokeWeight(1);
      }
      for (int i = 0; i < 4; i++) {
        p.stroke(255);
        p.fill(selectedCorners[i] ? p.color(255, 255, 0) : p.color(0, 255, 0));
        p.ellipse(corners[i].x, corners[i].y, 12, 12);
      }
    }
  }
  
  PVector getBilinearPoint(float u, float v, PVector[] pts) {
    PVector pTop = PVector.lerp(pts[0], pts[1], u);
    PVector pBottom = PVector.lerp(pts[3], pts[2], u);
    return PVector.lerp(pTop, pBottom, v);
  }
  
  void move(float dx, float dy) {
    for (PVector c : corners) c.add(dx, dy);
  }
  
  void moveSource(float du, float dv) {
    for (PVector c : sourceCorners) {
      c.x = constrain(c.x + du, 0, 1);
      c.y = constrain(c.y + dv, 0, 1);
    }
    sourceCorners[1].y = sourceCorners[0].y;
    sourceCorners[3].x = sourceCorners[0].x;
    sourceCorners[2].x = sourceCorners[1].x;
    sourceCorners[2].y = sourceCorners[3].y;
  }
  
  void moveSelectedCorners(float dx, float dy) {
    for (int i = 0; i < 4; i++) if (selectedCorners[i]) corners[i].add(dx, dy);
  }
  
  void moveSelectedSourceCorners(float du, float dv) {
    for (int i = 0; i < 4; i++) {
      if (selectedSourceCorners[i]) {
        sourceCorners[i].x = constrain(sourceCorners[i].x + du, 0, 1);
        sourceCorners[i].y = constrain(sourceCorners[i].y + dv, 0, 1);
        if (i == 0) { sourceCorners[1].y = sourceCorners[0].y; sourceCorners[3].x = sourceCorners[0].x; }
        else if (i == 1) { sourceCorners[0].y = sourceCorners[1].y; sourceCorners[2].x = sourceCorners[1].x; }
        else if (i == 2) { sourceCorners[3].y = sourceCorners[2].y; sourceCorners[1].x = sourceCorners[2].x; }
        else if (i == 3) { sourceCorners[2].y = sourceCorners[3].y; sourceCorners[0].x = sourceCorners[3].x; }
      }
    }
  }

  int getCornerAt(float x, float y, int xOffset) {
    float tx = x - xOffset; float ty = y;
    for (int i = 0; i < 4; i++) if (dist(tx, ty, corners[i].x, corners[i].y) < 15) return i;
    return -1;
  }

  int getEdgeAt(float x, float y, int xOffset) {
    float tx = x - xOffset; float ty = y;
    for (int i = 0; i < 4; i++) {
      PVector p1 = corners[i]; PVector p2 = corners[(i + 1) % 4];
      if (distToSegment(tx, ty, p1.x, p1.y, p2.x, p2.y) < 10) return i;
    }
    return -1;
  }

  float distToSegment(float px, float py, float x1, float y1, float x2, float y2) {
    float l2 = (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
    if (l2 == 0) return dist(px, py, x1, y1);
    float t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / l2;
    t = max(0, min(1, t));
    return dist(px, py, x1 + t * (x2 - x1), y1 + t * (y2 - y1));
  }
  
  int getSourceCornerAt(float x, float y, int xOffset, int viewWidth, PApplet p) {
    PImage tex = isVideo ? (videoFrame != null ? videoFrame : video) : img;
    if (tex == null) return -1;
    float aspect = (float)tex.width / tex.height;
    float drawW = viewWidth - 40; float drawH = drawW / aspect;
    if (drawH > p.height - 40) { drawH = p.height - 40; drawW = drawH * aspect; }
    float dx = (viewWidth - drawW) / 2 + xOffset;
    float dy = (p.height - drawH) / 2;
    for (int i = 0; i < 4; i++) if (dist(x, y, dx + sourceCorners[i].x * drawW, dy + sourceCorners[i].y * drawH) < 15) return i;
    return -1;
  }
  
  boolean isInside(float x, float y, int xOffset) {
    float tx = x - xOffset; float ty = y;
    int i, j; boolean c = false;
    for (i = 0, j = 3; i < 4; j = i++) {
      if (((corners[i].y > ty) != (corners[j].y > ty)) && (tx < (corners[j].x - corners[i].x) * (ty - corners[i].y) / (corners[j].y - corners[i].y) + corners[i].x)) c = !c;
    }
    return c;
  }
  
  boolean isInsideSource(float x, float y, int xOffset, int viewWidth, PApplet p) {
    PImage tex = isVideo ? (videoFrame != null ? videoFrame : video) : img;
    if (tex == null) return false;
    float aspect = (float)tex.width / tex.height;
    float drawW = viewWidth - 40; float drawH = drawW / aspect;
    if (drawH > p.height - 40) { drawH = p.height - 40; drawW = drawH * aspect; }
    float dx = (viewWidth - drawW) / 2 + xOffset; float dy = (p.height - drawH) / 2;
    float tx = (x - dx) / drawW; float ty = (y - dy) / drawH;
    float minX = min(sourceCorners[0].x, sourceCorners[2].x); float maxX = max(sourceCorners[0].x, sourceCorners[2].x);
    float minY = min(sourceCorners[0].y, sourceCorners[2].y); float maxY = max(sourceCorners[0].y, sourceCorners[2].y);
    return tx > minX && tx < maxX && ty > minY && ty < maxY;
  }
  
  void selectCornersInBox(float x1, float y1, float x2, float y2, int xOffset) {
    float tx1 = min(x1, x2) - xOffset; float ty1 = min(y1, y2);
    float tx2 = max(x1, x2) - xOffset; float ty2 = max(y1, y2);
    for (int i = 0; i < 4; i++) if (corners[i].x > tx1 && corners[i].x < tx2 && corners[i].y > ty1 && corners[i].y < ty2) selectedCorners[i] = true;
  }
  
  void clearSelection() {
    isSelected = false;
    for (int i = 0; i < 4; i++) { selectedCorners[i] = false; selectedSourceCorners[i] = false; }
  }
  
  void clearSourceSelection() { for (int i = 0; i < 4; i++) selectedSourceCorners[i] = false; }

  void printDiag(int idx) {
    println("  --- Surface[" + idx + "] ---");
    println("  mediaPath   : " + mediaPath);
    println("  isVideo     : " + isVideo);
    println("  isLive      : " + isLive);
    println("  isPlayground: " + isPlayground);
    if (isPlayground) {
      println("  pg canvas   : " + playground.canvas.width + " x " + playground.canvas.height);
    } else if (isLive || isVideo) {
      if (isLive) {
        println("  live canvas : " + liveAV.canvas.width + " x " + liveAV.canvas.height);
      } else if (video == null) {
        println("  video       : NULL");
      } else {
        println("  video dims  : " + video.width + " x " + video.height);
        println("  video time  : " + video.time());
      }
      if (bridgeG == null) {
        println("  bridgeG     : NULL");
      } else {
        bridgeG.loadPixels();
        int mid = bridgeG.pixels.length / 2;
        println("  bridgeG     : " + bridgeG.width + "x" + bridgeG.height
          + "  pixel[0]=" + hex(bridgeG.pixels[0])
          + "  pixel[mid]=" + hex(bridgeG.pixels[mid]));
      }
      if (videoFrame == null) {
        println("  videoFrame  : NULL");
      } else {
        videoFrame.loadPixels();
        int mid = videoFrame.pixels.length / 2;
        println("  videoFrame  : " + videoFrame.width + "x" + videoFrame.height
          + "  pixel[0]=" + hex(videoFrame.pixels[0])
          + "  pixel[mid]=" + hex(videoFrame.pixels[mid]));
      }
    } else {
      println("  img         : " + (img == null ? "NULL" : img.width + " x " + img.height));
    }
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    JSONArray jsonCorners = new JSONArray();
    for (int i = 0; i < 4; i++) { JSONObject cp = new JSONObject(); cp.setFloat("x", corners[i].x); cp.setFloat("y", corners[i].y); jsonCorners.setJSONObject(i, cp); }
    json.setJSONArray("corners", jsonCorners);
    JSONArray jsonSrc = new JSONArray();
    for (int i = 0; i < 4; i++) { JSONObject cp = new JSONObject(); cp.setFloat("x", sourceCorners[i].x); cp.setFloat("y", sourceCorners[i].y); jsonSrc.setJSONObject(i, cp); }
    json.setJSONArray("sourceCorners", jsonSrc);
    json.setString("mediaPath", mediaPath);
    json.setBoolean("isLive", isLive);
    json.setBoolean("isPlayground", isPlayground);
    return json;
  }
}
