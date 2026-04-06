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
  PImage videoFrame; // The bridge image used for multi-window output
  String mediaPath = "";
  boolean isVideo = false;
  
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
  }
  
  void loadMedia(PApplet parent, String path) {
    this.mediaPath = path;
    String lowerPath = path.toLowerCase();
    if (lowerPath.endsWith(".mp4") || lowerPath.endsWith(".mov") || lowerPath.endsWith(".avi")) {
      try {
        video = new Movie(parent, path);
        video.loop();
        isVideo = true;
        img = null;
        videoFrame = null;
      } catch (Exception e) {
        println("Error loading video: " + e.getMessage());
      }
    } else {
      img = parent.loadImage(path);
      isVideo = false;
      video = null;
      videoFrame = null;
    }
  }

  /**
   * Copies the current Movie frame into a PImage bridge so it can be safely
   * used as a texture in both the controller and output window OpenGL contexts.
   * Called each draw() from the primary applet thread after movieEvent has fired.
   */
  void updateVideoBridge() {
    if (!isVideo || video == null || video.width == 0 || video.height == 0) return;

    if (videoFrame == null || videoFrame.width != video.width || videoFrame.height != video.height) {
      videoFrame = createImage(video.width, video.height, RGB);
    }

    video.loadPixels();
    videoFrame.loadPixels();
    System.arraycopy(video.pixels, 0, videoFrame.pixels, 0, video.pixels.length);
    videoFrame.updatePixels();
  }

  void display(PApplet p, boolean isController, int xOffset, int viewWidth, boolean isSourceView) {
    // videoFrame is the pixel-copied bridge; fall back to the Movie itself if not yet populated
    PImage tex = isVideo ? (videoFrame != null ? videoFrame : video) : img;
    
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
    if (tex != null) {
      p.noStroke();
      p.beginShape(QUADS);
      p.texture(tex);
      p.textureMode(NORMAL);
      for (int y = 0; y < gridRes; y++) {
        for (int x = 0; x < gridRes; x++) {
          float u1 = (float)x / gridRes; float v1 = (float)y / gridRes;
          float u2 = (float)(x+1) / gridRes; float v2 = (float)(y+1) / gridRes;
          PVector p1 = getBilinearPoint(u1, v1, corners);
          PVector p2 = getBilinearPoint(u2, v1, corners);
          PVector p3 = getBilinearPoint(u2, v2, corners);
          PVector p4 = getBilinearPoint(u1, v2, corners);
          PVector t1 = getBilinearPoint(u1, v1, sourceCorners);
          PVector t2 = getBilinearPoint(u2, v1, sourceCorners);
          PVector t3 = getBilinearPoint(u2, v2, sourceCorners);
          PVector t4 = getBilinearPoint(u1, v2, sourceCorners);
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
    if (isVideo) {
      if (video == null) {
        println("  video       : NULL");
      } else {
        println("  video dims  : " + video.width + " x " + video.height);
        println("  video time  : " + video.time() + " / " + video.duration());
        println("  video.available(): " + video.available());
        // Sample a few pixels to detect black vs real content
        if (video.width > 0 && video.height > 0) {
          video.loadPixels();
          int mid = video.pixels.length / 2;
          println("  pixel[0]    : " + hex(video.pixels[0]));
          println("  pixel[mid]  : " + hex(video.pixels[mid]));
          println("  pixel[-1]   : " + hex(video.pixels[video.pixels.length - 1]));
        }
      }
      if (videoFrame == null) {
        println("  videoFrame  : NULL (bridge not yet created)");
      } else {
        println("  videoFrame  : " + videoFrame.width + " x " + videoFrame.height + "  format=" + videoFrame.format);
        videoFrame.loadPixels();
        int mid = videoFrame.pixels.length / 2;
        println("  vfPixel[0]  : " + hex(videoFrame.pixels[0]));
        println("  vfPixel[mid]: " + hex(videoFrame.pixels[mid]));
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
    return json;
  }
}
