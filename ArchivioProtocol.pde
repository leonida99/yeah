import queasycam.*;
import ddf.minim.*;
import ddf.minim.ugens.*;

// =========================
// ENGINE
// =========================
QueasyCam cam;
Minim minim;
AudioOutput out;
Oscil humTone;

// =========================
// STATI NARRATIVI
// =========================
final int STATE_TITLE = 0;
final int STATE_EXPLORATION = 1;
final int STATE_ESCAPE = 2;
final int STATE_END = 3;

int gameState = STATE_TITLE;

String chapterTitle = "CAPITOLO I // STANZA SENZA OROLOGI";
String objectiveText = "Trova i 4 Frammenti di Memoria.";
String endingTitle = "";
String endingBody = "";

final float ENTITY_CATCH_DISTANCE_EXPLORE = 95;
final float ENTITY_CATCH_DISTANCE_ESCAPE = 105;
final float EXIT_REACH_DISTANCE = 150;
final int ENTITY_TELEPORT_MEMORY_THRESHOLD = 3;
final int ENTITY_TELEPORT_FRAME_INTERVAL = 360;
final float ENTITY_TELEPORT_RADIUS = 300;
final int WHISPER_BASE_DURATION = 130;
final int WHISPER_DURATION_VARIANCE = 120;
final float ENTITY_SPEED_AGGRESSIVE = 5.6;
final float ENTITY_SPEED_BASE = 2.9;
final float ENTITY_SPEED_FEAR_MULTIPLIER = 0.7;

// =========================
// MAPPA E MONDO
// =========================
int blockSize = 280;

// 1 = muro, 0 = vuoto, 2 = frammento, 3 = uscita, 4 = monolite, 5 = spawn
int[][] mapTemplate = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,5,0,0,0,0,1,0,0,0,1,0,0,0,0,3,1},
  {1,1,1,1,1,0,1,0,1,0,1,0,1,1,1,0,1},
  {1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,1},
  {1,0,1,0,1,1,1,0,1,1,1,0,1,0,1,1,1},
  {1,0,1,0,0,0,1,0,0,0,1,0,0,0,2,0,1},
  {1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,0,1},
  {1,0,0,0,1,0,0,0,1,0,0,0,1,0,1,0,1},
  {1,1,1,0,1,1,1,4,1,1,1,0,1,0,1,0,1},
  {1,0,0,0,0,0,1,0,0,0,1,0,0,0,1,0,1},
  {1,0,1,1,1,0,1,1,1,0,1,1,1,1,1,0,1},
  {1,0,1,2,0,0,0,0,1,0,0,0,2,0,0,0,1},
  {1,0,1,1,1,1,1,0,1,1,1,0,1,1,1,0,1},
  {1,0,0,0,0,0,1,0,0,0,1,0,0,0,1,0,1},
  {1,1,1,1,1,0,1,1,1,0,1,1,1,0,1,0,1},
  {1,0,0,0,2,0,0,0,0,0,0,0,1,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
};

int[][] levelMap;
PVector spawnPos;
PVector exitPos;
PVector altarPos;
PVector prevPos;

ArrayList<PVector> memoryShards = new ArrayList<PVector>();
int memoriesRecovered = 0;
int totalMemories = 0;
boolean architectureShifted = false;

// =========================
// ENTITÀ
// =========================
PVector entityPos;
boolean entityAwake = false;

// =========================
// INPUT EDGE
// =========================
boolean prevE = false;
boolean prevR = false;
boolean prevSpace = false;
boolean justE = false;
boolean justR = false;
boolean justSpace = false;

// =========================
// ATMOSFERA
// =========================
float fear = 0.0;
String[] whispers = {
  "Non stai tornando indietro. Il corridoio sta tornando su di te.",
  "La tua memoria non ti appartiene più.",
  "Il monolite ha il tuo stesso respiro.",
  "Hai già fatto questa fuga 47 volte.",
  "Le luci non si spengono: ti stanno misurando.",
  "Non cercare l'uscita. Cerca chi eri.",
  "Ogni porta è una versione di te che non ha retto.",
  "Quando senti silenzio... stai ascoltando lui."
};
String activeWhisper = "";
int whisperUntil = 0;
int nextWhisper = 180;

// =========================
// GRAFICA PROCEDURALE
// =========================
PGraphics wallTex, floorTex, ceilTex;

void setup() {
  fullScreen(P3D);
  noCursor();
  textureWrap(REPEAT);
  frameRate(60);

  generateTextures();
  initCamera();
  initAudio();
  resetGame();
}

void initCamera() {
  cam = new QueasyCam(this);
  cam.speed = 4.0;
  cam.sensitivity = 0.62;
}

void initAudio() {
  minim = new Minim(this);
  out = minim.getLineOut();
  humTone = new Oscil(48, 0.09f, Waves.SAW);
  humTone.patch(out);
}

void resetGame() {
  gameState = STATE_TITLE;
  chapterTitle = "CAPITOLO I // STANZA SENZA OROLOGI";
  objectiveText = "Trova i 4 Frammenti di Memoria.";
  endingTitle = "";
  endingBody = "";

  memoriesRecovered = 0;
  architectureShifted = false;
  entityAwake = false;
  fear = 0.0;

  activeWhisper = "";
  whisperUntil = 0;
  nextWhisper = frameCount + 150;

  buildMap();
  parseMapMarkers();

  cam.position = spawnPos.copy();
  prevPos = cam.position.copy();
  entityPos = new PVector((levelMap[0].length * blockSize) / 2.0, 0, (levelMap.length * blockSize) / 2.0);

  humTone.setFrequency(48);
  humTone.setAmplitude(0.09f);
  humTone.setWaveform(Waves.SAW);
}

void buildMap() {
  levelMap = new int[mapTemplate.length][mapTemplate[0].length];
  for (int z = 0; z < mapTemplate.length; z++) {
    for (int x = 0; x < mapTemplate[0].length; x++) {
      levelMap[z][x] = mapTemplate[z][x];
    }
  }
}

void parseMapMarkers() {
  memoryShards.clear();
  spawnPos = null;
  exitPos = null;
  altarPos = null;

  for (int z = 0; z < levelMap.length; z++) {
    for (int x = 0; x < levelMap[0].length; x++) {
      int cell = levelMap[z][x];
      float wx = x * blockSize + blockSize/2;
      float wz = z * blockSize + blockSize/2;

      if (cell == 5 && spawnPos == null) {
        spawnPos = new PVector(wx, -100, wz);
        levelMap[z][x] = 0;
      } else if (cell == 3 && exitPos == null) {
        exitPos = new PVector(wx, -100, wz);
      } else if (cell == 4 && altarPos == null) {
        altarPos = new PVector(wx, -60, wz);
        levelMap[z][x] = 0;
      } else if (cell == 2) {
        memoryShards.add(new PVector(wx, -60, wz));
        levelMap[z][x] = 0;
      }
    }
  }

  if (spawnPos == null) spawnPos = new PVector(blockSize + blockSize/2, -100, blockSize + blockSize/2);
  if (exitPos == null) exitPos = new PVector((levelMap[0].length - 2) * blockSize + blockSize/2, -100, blockSize + blockSize/2);
  if (altarPos == null) altarPos = new PVector((levelMap[0].length/2) * blockSize + blockSize/2, -60, (levelMap.length/2) * blockSize + blockSize/2);

  totalMemories = memoryShards.size();
}

void draw() {
  captureInputEdges();

  if (gameState == STATE_TITLE) drawTitle();
  else if (gameState == STATE_EXPLORATION) runExploration();
  else if (gameState == STATE_ESCAPE) runEscape();
  else if (gameState == STATE_END) drawEnding();
}

void captureInputEdges() {
  boolean currE = keyPressed && (key == 'e' || key == 'E');
  boolean currR = keyPressed && (key == 'r' || key == 'R');
  boolean currSpace = keyPressed && key == ' ';

  justE = currE && !prevE;
  justR = currR && !prevR;
  justSpace = currSpace && !prevSpace;

  prevE = currE;
  prevR = currR;
  prevSpace = currSpace;
}

void drawTitle() {
  background(0);
  hint(DISABLE_DEPTH_TEST);
  pushMatrix();
  camera();
  noLights();

  float pulse = 120 + sin(frameCount * 0.03) * 60;
  fill(pulse, pulse, pulse + 20);
  textAlign(CENTER, CENTER);
  textSize(44);
  text("PROTOCOLLO NARCISO", width/2, height/2 - 160);

  textSize(22);
  fill(220);
  text("Sei l'Archivista 9.\nHai perso i ricordi dell'ultima notte.\nIn questo settore ogni stanza è una versione di te.", width/2, height/2 - 45);

  textSize(20);
  fill(180, 210, 255);
  text("WASD muovi  •  Mouse visuale  •  E interagisci  •  R rifiuta", width/2, height/2 + 70);
  text("Premi [SPAZIO] per entrare.", width/2, height/2 + 120);

  popMatrix();
  hint(ENABLE_DEPTH_TEST);

  if (justSpace) {
    gameState = STATE_EXPLORATION;
    chapterTitle = "CAPITOLO I // STANZA SENZA OROLOGI";
    objectiveText = "Trova i 4 Frammenti di Memoria.";
    humTone.setFrequency(52);
  }
}

void runExploration() {
  updateFear();
  updateAudio();
  updateWhispers();

  float blue = 160 - fear * 90;
  float green = 158 - fear * 65;
  background(120, green, blue);
  ambientLight(190 - fear * 80, 185 - fear * 70, 165 - fear * 90);
  pointLight(255, 240, 200, cam.position.x, -90, cam.position.z);

  handlePhysics();
  renderWorld();
  renderNarrativeProps();
  handleMemoryInteraction();
  handleAltarChoice();

  if (entityAwake) {
    updateEntity(false);
    renderEntity();
  }

  if (entityAwake && dist(cam.position.x, cam.position.z, entityPos.x, entityPos.z) < ENTITY_CATCH_DISTANCE_EXPLORE) {
    triggerEnding(
      "FINE // ASSORBIMENTO",
      "Hai provato a correre, ma il corridoio\nha scelto il tuo passo.\n\nL'Archivio ora ricorda al posto tuo."
      );
  }

  drawHUD();
  drawPsychologicalOverlay();
}

void runEscape() {
  updateFear();
  updateAudio();
  updateWhispers();

  float alarm = (sin(frameCount * 0.14) + 1) * 120;
  background(18, 2, 4);
  ambientLight(35 + alarm * 0.2, 0, 0);
  pointLight(255, 0, 0, cam.position.x, -80, cam.position.z);

  handlePhysics();
  renderWorld();
  renderNarrativeProps();
  updateEntity(true);
  renderEntity();

  if (dist(cam.position.x, cam.position.z, entityPos.x, entityPos.z) < ENTITY_CATCH_DISTANCE_ESCAPE) {
    triggerEnding(
      "FINE // SPECCHIO CHIUSO",
      "Hai rifiutato il monolite,\nma non il suo riflesso.\n\nNel settore restano due respiri: il tuo e il suo."
      );
  }

  if (dist(cam.position.x, cam.position.z, exitPos.x, exitPos.z) < EXIT_REACH_DISTANCE) {
    triggerEnding(
      "FINE // FUGA IMPERFETTA",
      "La porta si è aperta.\nFuori piove luce bianca.\n\nHai salvato il corpo,\nma una copia di te è rimasta dentro."
      );
  }

  drawHUD();
  drawPsychologicalOverlay();
}

void drawEnding() {
  background(0);
  hint(DISABLE_DEPTH_TEST);
  pushMatrix();
  camera();
  noLights();

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(40);
  text(endingTitle, width/2, height/2 - 110);

  textSize(24);
  fill(220);
  text(endingBody, width/2, height/2);

  textSize(20);
  fill(170, 210, 255);
  text("Premi [SPAZIO] per ricominciare  •  ESC per uscire", width/2, height/2 + 170);

  popMatrix();
  hint(ENABLE_DEPTH_TEST);

  if (justSpace) {
    resetGame();
  }
}

void triggerEnding(String title, String body) {
  endingTitle = title;
  endingBody = body;
  gameState = STATE_END;
  humTone.setFrequency(34);
  humTone.setWaveform(Waves.SINE);
  humTone.setAmplitude(0.11f);
}

void updateFear() {
  float target = 0.1 + memoriesRecovered * 0.17;
  if (entityAwake) target += 0.2;
  if (gameState == STATE_ESCAPE) target = 0.95;
  fear = lerp(fear, constrain(target, 0, 1), 0.03);
}

void updateAudio() {
  float base = 50 + fear * 24;
  if (gameState == STATE_ESCAPE) {
    base = 95 + sin(frameCount * 0.1) * 18;
    humTone.setWaveform(Waves.SQUARE);
  } else {
    humTone.setWaveform(Waves.SAW);
  }
  humTone.setFrequency(base);
  humTone.setAmplitude(0.07f + fear * 0.08f);
}

void updateWhispers() {
  if (gameState == STATE_TITLE || gameState == STATE_END) return;

  if (frameCount > nextWhisper) {
    activeWhisper = whispers[(int)random(whispers.length)];
    whisperUntil = frameCount + (int)(WHISPER_BASE_DURATION + random(WHISPER_DURATION_VARIANCE));

    float gap = 280 - fear * 170;
    nextWhisper = frameCount + (int)(max(80, gap) + random(140));
  }
}

void handleMemoryInteraction() {
  if (memoryShards.size() == 0) return;

  for (int i = memoryShards.size() - 1; i >= 0; i--) {
    PVector m = memoryShards.get(i);
    float d = dist(cam.position.x, cam.position.z, m.x, m.z);
    if (d < 145) {
      showPrompt("Premi [E] per ricostruire il ricordo");
      if (justE) {
        memoryShards.remove(i);
        memoriesRecovered++;
        onMemoryRecovered();
      }
      break;
    }
  }
}

void onMemoryRecovered() {
  if (memoriesRecovered == 1) {
    objectiveText = "Ne restano " + (totalMemories - memoriesRecovered) + ". Le pareti hanno iniziato a respirare.";
  } else if (memoriesRecovered == 2) {
    chapterTitle = "CAPITOLO II // IL CORRIDOIO TI OSSERVA";
    objectiveText = "Completa i ricordi. Poi raggiungi il Monolite.";
    entityAwake = true;
    shiftArchitecture();
    activeWhisper = "Hai aperto la stanza sbagliata.";
    whisperUntil = frameCount + 180;
  } else if (memoriesRecovered < totalMemories) {
    objectiveText = "Ne restano " + (totalMemories - memoriesRecovered) + ".";
  } else {
    objectiveText = "Raggiungi il Monolite al centro e scegli chi vuoi essere.";
    activeWhisper = "Ora non puoi più fingere.";
    whisperUntil = frameCount + 220;
  }
}

void shiftArchitecture() {
  if (architectureShifted) return;
  architectureShifted = true;

  // Sigilla alcuni corridoi familiari per spezzare il percorso memorizzato.
  PVector[] closePassages = {
    new PVector(5, 3), new PVector(5, 4), new PVector(10, 9), new PVector(14, 13)
  };
  // Apre nuovi varchi innaturali per creare un layout "impossibile".
  PVector[] openPassages = {
    new PVector(7, 2), new PVector(11, 8), new PVector(2, 14), new PVector(14, 10)
  };

  for (int i = 0; i < closePassages.length; i++) {
    setCell((int)closePassages[i].x, (int)closePassages[i].y, 1);
  }
  for (int i = 0; i < openPassages.length; i++) {
    setCell((int)openPassages[i].x, (int)openPassages[i].y, 0);
  }
}

void setCell(int x, int z, int value) {
  if (z < 0 || z >= levelMap.length || x < 0 || x >= levelMap[0].length) return;
  if (levelMap[z][x] == 3) return;
  levelMap[z][x] = value;
}

void handleAltarChoice() {
  if (memoryShards.size() > 0) return;

  float d = dist(cam.position.x, cam.position.z, altarPos.x, altarPos.z);
  if (d < 180) {
    showPrompt("Monolite: [E] Accetta la memoria totale   •   [R] Rifiuta e fuggi");
    if (justE) {
      triggerEnding(
        "FINE // EPIFANIA VUOTA",
        "Hai scelto di ricordare tutto.\n\nOra conosci ogni dolore,\nogni menzogna, ogni versione di te.\nNessuna è sopravvissuta."
        );
    } else if (justR) {
      gameState = STATE_ESCAPE;
      chapterTitle = "CAPITOLO III // USCITA ROSSA";
      objectiveText = "Corri verso la porta del settore prima che ti raggiunga.";
      entityAwake = true;
      activeWhisper = "Le tue gambe sono veloci. Il corridoio di più.";
      whisperUntil = frameCount + 180;
    }
  }
}

void updateEntity(boolean aggressive) {
  if (!entityAwake) return;

  float targetX = cam.position.x;
  float targetZ = cam.position.z;

  float dx = targetX - entityPos.x;
  float dz = targetZ - entityPos.z;
  float magSq = dx * dx + dz * dz;

  if (magSq > 0.0001f) {
    float inv = 1.0 / sqrt(magSq);
    dx *= inv;
    dz *= inv;
  }

  float speed = aggressive ? ENTITY_SPEED_AGGRESSIVE : ENTITY_SPEED_BASE + fear * ENTITY_SPEED_FEAR_MULTIPLIER;
  entityPos.add(dx * speed, 0, dz * speed);

  if (!aggressive && memoriesRecovered >= ENTITY_TELEPORT_MEMORY_THRESHOLD && frameCount % ENTITY_TELEPORT_FRAME_INTERVAL == 0) {
    float ang = random(TWO_PI);
    entityPos.x = cam.position.x + cos(ang) * ENTITY_TELEPORT_RADIUS;
    entityPos.z = cam.position.z + sin(ang) * ENTITY_TELEPORT_RADIUS;
  }
}

void handlePhysics() {
  float pR = 40;
  boolean hitX = false;
  boolean hitZ = false;

  if (isSolidAt(cam.position.x + pR, prevPos.z) || isSolidAt(cam.position.x - pR, prevPos.z)) hitX = true;
  if (isSolidAt(prevPos.x, cam.position.z + pR) || isSolidAt(prevPos.x, cam.position.z - pR)) hitZ = true;

  if (hitX) cam.position.x = prevPos.x;
  if (hitZ) cam.position.z = prevPos.z;
  if (isSolidAt(cam.position.x, cam.position.z)) cam.position = prevPos.copy();

  float maxX = levelMap[0].length * blockSize - blockSize;
  float maxZ = levelMap.length * blockSize - blockSize;
  cam.position.x = constrain(cam.position.x, blockSize, maxX);
  cam.position.z = constrain(cam.position.z, blockSize, maxZ);

  prevPos = cam.position.copy();
}

boolean isSolidAt(float px, float pz) {
  int gridX = constrain(floor(px / blockSize), 0, levelMap[0].length - 1);
  int gridZ = constrain(floor(pz / blockSize), 0, levelMap.length - 1);
  int cell = levelMap[gridZ][gridX];
  if (cell == 1) return true;
  if (cell == 3 && gameState != STATE_ESCAPE) return true;
  return false;
}

void renderWorld() {
  noStroke();
  float mapW = levelMap[0].length * blockSize;
  float mapH = levelMap.length * blockSize;

  // Pareti
  for (int z = 0; z < levelMap.length; z++) {
    for (int x = 0; x < levelMap[0].length; x++) {
      int cell = levelMap[z][x];
      float wx = x * blockSize + blockSize/2;
      float wz = z * blockSize + blockSize/2;

      if (cell == 1) {
        drawTexturedWallCube(wx, wz);
      } else if (cell == 3) {
        drawExitDoor(wx, wz);
      }
    }
  }

  // Pavimento + soffitto
  pushMatrix();
  translate(mapW/2, 0, mapH/2);

  beginShape(QUADS);
  textureMode(NORMAL);
  texture(floorTex);
  vertex(-mapW/2, 0, -mapH/2, 0, 0);
  vertex(mapW/2, 0, -mapH/2, 22, 0);
  vertex(mapW/2, 0, mapH/2, 22, 22);
  vertex(-mapW/2, 0, mapH/2, 0, 22);
  endShape();

  translate(0, -blockSize, 0);
  beginShape(QUADS);
  textureMode(NORMAL);
  texture(ceilTex);
  vertex(-mapW/2, 0, -mapH/2, 0, 0);
  vertex(mapW/2, 0, -mapH/2, 22, 0);
  vertex(mapW/2, 0, mapH/2, 22, 22);
  vertex(-mapW/2, 0, mapH/2, 0, 22);
  endShape();

  popMatrix();
}

void drawTexturedWallCube(float wx, float wz) {
  pushMatrix();
  translate(wx, -blockSize/2, wz);

  beginShape(QUADS);
  textureMode(NORMAL);
  texture(wallTex);

  // +X
  vertex(blockSize/2, -blockSize/2, -blockSize/2, 0, 0);
  vertex(blockSize/2, -blockSize/2, blockSize/2, 1, 0);
  vertex(blockSize/2, blockSize/2, blockSize/2, 1, 1);
  vertex(blockSize/2, blockSize/2, -blockSize/2, 0, 1);

  // -X
  vertex(-blockSize/2, -blockSize/2, blockSize/2, 0, 0);
  vertex(-blockSize/2, -blockSize/2, -blockSize/2, 1, 0);
  vertex(-blockSize/2, blockSize/2, -blockSize/2, 1, 1);
  vertex(-blockSize/2, blockSize/2, blockSize/2, 0, 1);

  // +Z
  vertex(blockSize/2, -blockSize/2, blockSize/2, 0, 0);
  vertex(-blockSize/2, -blockSize/2, blockSize/2, 1, 0);
  vertex(-blockSize/2, blockSize/2, blockSize/2, 1, 1);
  vertex(blockSize/2, blockSize/2, blockSize/2, 0, 1);

  // -Z
  vertex(-blockSize/2, -blockSize/2, -blockSize/2, 0, 0);
  vertex(blockSize/2, -blockSize/2, -blockSize/2, 1, 0);
  vertex(blockSize/2, blockSize/2, -blockSize/2, 1, 1);
  vertex(-blockSize/2, blockSize/2, -blockSize/2, 0, 1);
  endShape();

  popMatrix();
}

void drawExitDoor(float wx, float wz) {
  pushMatrix();
  translate(wx, -110, wz);
  float pulse = 0.5 + 0.5 * sin(frameCount * 0.12);
  if (gameState == STATE_ESCAPE) fill(40 + pulse * 120, 240, 80 + pulse * 80);
  else fill(170 + pulse * 40, 30, 35);
  box(blockSize * 0.85, 220, 40);
  popMatrix();
}

void renderNarrativeProps() {
  // Frammenti
  for (int i = 0; i < memoryShards.size(); i++) {
    PVector m = memoryShards.get(i);
    float wobble = sin(frameCount * 0.07 + i) * 11;
    pushMatrix();
    translate(m.x, m.y + wobble, m.z);
    rotateY(frameCount * 0.03 + i);
    rotateX(frameCount * 0.02 + i * 0.2);
    fill(110, 220, 255, 230);
    stroke(220, 250, 255);
    strokeWeight(2);
    box(36, 56, 14);
    popMatrix();
  }

  // Monolite
  pushMatrix();
  translate(altarPos.x, -140, altarPos.z);
  float pulse = 0.55 + 0.45 * sin(frameCount * 0.05);
  fill(15 + pulse * 40, 15 + pulse * 45, 25 + pulse * 65);
  stroke(120 + pulse * 80, 160 + pulse * 80, 255);
  strokeWeight(2);
  box(120, 280, 120);

  noStroke();
  fill(130 + pulse * 120, 200 + pulse * 45, 255, 150);
  translate(0, -40, 61);
  rect(-26, -36, 52, 72);
  popMatrix();
}

void renderEntity() {
  float deform = sin(frameCount * 0.21) * 18;
  float jitter = sin(frameCount * 0.67) * 6;

  pushMatrix();
  translate(entityPos.x + jitter, -100, entityPos.z - jitter);
  rotateY(frameCount * 0.08);
  rotateX(frameCount * 0.04);
  fill(0);
  stroke(255, 20, 40);
  strokeWeight(3);
  box(80 + deform, 185 + deform * 0.5, 55 + deform * 0.3);
  popMatrix();
}

void drawHUD() {
  hint(DISABLE_DEPTH_TEST);
  pushMatrix();
  camera();
  noLights();

  fill(230);
  textAlign(LEFT, TOP);
  textSize(20);
  text(chapterTitle, 20, 18);
  textSize(18);
  text(objectiveText, 20, 48);

  textSize(18);
  text("Memorie: " + memoriesRecovered + "/" + totalMemories, 20, 78);

  fill(255, 170);
  noStroke();
  ellipse(width/2, height/2, 5, 5);

  popMatrix();
  hint(ENABLE_DEPTH_TEST);
}

void showPrompt(String txt) {
  hint(DISABLE_DEPTH_TEST);
  pushMatrix();
  camera();
  noLights();

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(24);
  text(txt, width/2, height/2 + 65);

  popMatrix();
  hint(ENABLE_DEPTH_TEST);
}

void drawPsychologicalOverlay() {
  hint(DISABLE_DEPTH_TEST);
  pushMatrix();
  camera();
  noLights();

  int lines = (int)(35 + fear * 130);
  stroke(255, 255, 255, 18 + fear * 35);
  for (int i = 0; i < lines; i++) {
    float y = random(height);
    line(0, y, width, y + random(-2, 2));
  }

  if (gameState == STATE_ESCAPE) {
    noStroke();
    fill(255, 20, 20, 20 + sin(frameCount * 0.25) * 16);
    rect(0, 0, width, height);
  }

  if (frameCount < whisperUntil && activeWhisper.length() > 0) {
    fill(200 + random(55), 210 + random(45), 255, 180);
    textAlign(CENTER, BOTTOM);
    textSize(26);
    text(activeWhisper, width/2, height - 45);
  }

  noFill();
  stroke(0, 0, 0, 120 + fear * 80);
  strokeWeight(28);
  rect(0, 0, width, height);

  popMatrix();
  hint(ENABLE_DEPTH_TEST);
}

void generateTextures() {
  wallTex = createGraphics(256, 256);
  wallTex.beginDraw();
  wallTex.background(122, 114, 102);
  wallTex.noStroke();
  for (int i = 0; i < 900; i++) {
    float b = random(90, 150);
    wallTex.fill(b, b - 8, b - 15, 90);
    wallTex.rect(random(256), random(256), random(2, 7), random(2, 7));
  }
  wallTex.stroke(94, 90, 82, 130);
  for (int y = 0; y < 256; y += 32) wallTex.line(0, y, 256, y);
  wallTex.stroke(80, 76, 70, 110);
  for (int i = 0; i < 28; i++) {
    float x = random(30, 226);
    float y = random(30, 226);
    wallTex.line(x, y, x + random(-25, 25), y + random(-40, 40));
  }
  wallTex.endDraw();

  floorTex = createGraphics(256, 256);
  floorTex.beginDraw();
  floorTex.background(63, 66, 70);
  floorTex.stroke(90, 92, 95);
  for (int x = 0; x < 256; x += 28) floorTex.line(x, 0, x, 256);
  for (int y = 0; y < 256; y += 28) floorTex.line(0, y, 256, y);
  floorTex.noStroke();
  for (int i = 0; i < 200; i++) {
    floorTex.fill(120, 130, 140, random(25, 70));
    floorTex.ellipse(random(256), random(256), random(10, 24), random(8, 18));
  }
  floorTex.endDraw();

  ceilTex = createGraphics(256, 256);
  ceilTex.beginDraw();
  ceilTex.background(202, 203, 196);
  ceilTex.noStroke();
  for (int i = 0; i < 48; i++) {
    float x = random(20, 236);
    float y = random(20, 236);
    ceilTex.fill(232, 235, 226, 180);
    ceilTex.rect(x - 12, y - 8, 24, 16);
  }
  ceilTex.stroke(176, 178, 170, 110);
  for (int y = 0; y < 256; y += 18) ceilTex.line(0, y, 256, y);
  ceilTex.stroke(210, 235, 255, 45);
  for (int x = 0; x < 256; x += 48) {
    ceilTex.line(x, 0, x + 20, 256);
  }
  ceilTex.endDraw();
}

void dispose() {
  if (humTone != null && out != null) humTone.unpatch(out);
  if (out != null) out.close();
  if (minim != null) minim.stop();
}
