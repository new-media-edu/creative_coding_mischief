/**
 * IO Module
 * Handles file selection, media loading, and JSON configuration.
 */

void addQuad() {
  synchronized(surfaces) {
    Surface s = new Surface(this);
    surfaces.add(s);
    clearAllSelections();
    s.isSelected = true;
    selectedSurface = s;
  }
}

void toggleSourceView() { 
  showSourceView = !showSourceView; 
}

void toggleLiveAction() {
  if (selectedSurface != null) {
    synchronized(surfaces) {
      selectedSurface.setLive(!selectedSurface.isLive);
    }
  }
}

void loadMediaAction() {
  if (selectedSurface != null) {
    selectInput("Select media:", "fileSelected");
  }
}

void deleteAction() {
  if (selectedSurface != null) {
    synchronized(surfaces) {
      selectedSurface.unloadMedia();
      surfaces.remove(selectedSurface);
      selectedSurface = null;
    }
  }
}

void fileSelected(File selection) {
  if (selection != null && selectedSurface != null) {
    synchronized(surfaces) {
      selectedSurface.loadMedia(this, selection.getAbsolutePath());
    }
  }
}

void saveConfig() {
  synchronized(surfaces) {
    JSONArray jsonSurfaces = new JSONArray();
    for (int i = 0; i < surfaces.size(); i++) {
      jsonSurfaces.setJSONObject(i, surfaces.get(i).toJSON());
    }
    saveJSONArray(jsonSurfaces, "data/config.json");
  }
  println("Configuration saved to data/config.json");
}

void loadConfig() {
  File f = new File(sketchPath("data/config.json"));
  if (f.exists()) {
    synchronized(surfaces) {
      JSONArray jsonSurfaces = loadJSONArray("data/config.json");
      for (int i = 0; i < jsonSurfaces.size(); i++) {
        surfaces.add(new Surface(this, jsonSurfaces.getJSONObject(i)));
      }
    }
    println("Configuration loaded.");
  }
}
