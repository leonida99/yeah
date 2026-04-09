import queasycam.*;
import ddf.minim.*;
import ddf.minim.ugens.*;

// --- ENGINE ---
QueasyCam cam;
Minim minim;
AudioOutput out;
Oscil humTone;

// --- ASSET PROCEDURALI ---
PGraphics wallTex, floorTex, ceilTex;

// --- MAPPA (15x15) ---
// 1=Muro, 0=Vuoto, 2=Terminale, 3=Spawn/Uscita
int blockSize = 300;
int[][] levelMap = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,3,0,0,1,0,0,0,0,0,1,2,0,0,1},
  {1,1,1,0,1,0,1,1,1,0,1,1,1,0,1},
  {1,0,0,0,0,0,1,2,1,0,0,0,0,0,1},
  {1,0,1,1,1,0,1,0,1,1,1,1,1,0,1},
  {1,0,1,0,0,0,0,0,0,0,0,0,1,0,1},
  {1,0,1,0,1,1,1,0,1,1,1,0,1,0,1},
  {1,0,0,0,1,0,0,0,0,0,1,0,0,0,1},
  {1,1,1,0,1,0,1,1,1,0,1,0,1,1,1},
  {1,0,0,0,0,0,1,0,0,0,0,0,0,0,1},
  {1,0,1,1,1,1,1,0,1,1,1,1,1,0,1},
  {1,0,0,0,1,0,0,0,1,2,0,0,0,0,1},
  {1,1,1,0,1,0,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
};

// --- GAMEPLAY STATS ---
int state = 0; // 0: Intro, 1: Esplorazione, 2: Fuga, 3: Finale
int terminalsFixed = 0;
int maxTerminals = 3;
PVector spawnPos;
ArrayList<PVector> terminals = new ArrayList<PVector>();
String narrativeText = "Trova e riavvia i 3 Terminali.";

// --- ENTITA' ---
PVector entityPos;
PVector prevPos;
boolean interactPressed = false;
boolean spawnAssigned = false;

final float INTERACTION_DISTANCE = 150;
final float ENTITY_CAPTURE_DISTANCE = 100;
final float ESCAPE_ZONE_RADIUS = 150;
final float ENTITY_JITTER_MIN = -10;
final float ENTITY_JITTER_MAX = 10;
final float MIN_DIRECTION_THRESHOLD = 0.0001f;

void setup() {
  fullScreen(P3D);
  noCursor();
  textureWrap(REPEAT);

  generateTextures();

  cam = new QueasyCam(this);
  cam.speed = 4.0;
  cam.sensitivity = 0.6;

  minim = new Minim(this);
  out = minim.getLineOut();
  humTone = new Oscil(60, 0.1f, Waves.SINE);
  humTone.patch(out);

  parseMap();
  prevPos = cam.position.copy();
}

void draw() {
  if (state == 0) drawIntro();
  else if (state == 1) playExplorationPhase();
  else if (state == 2) playChasePhase();
  else if (state == 3) drawOutro();
}

void drawIntro() {
  background(0);
  hint(DISABLE_DEPTH_TEST);
  pushMatrix();
  camera();
  noLights();

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(32);
  text("PROTOCOLLO DI RECUPERO DATI", width/2, height/2 - 50);
  textSize(20);
  text("Sei nel Settore 0.\nRiavvia i 3 terminali per sbloccare l'uscita.\nUsa [W A S D] per muoverti. Mouse per la visuale.\n\nPremi [SPAZIO] per iniziare.", width/2, height/2 + 50);

  popMatrix();
  hint(ENABLE_DEPTH_TEST);

  if (keyPressed && key == ' ') {
    state = 1;
    humTone.setFrequency(55);
  }
}

void playExplorationPhase() {
  background(200, 200, 150);
  ambientLight(220, 220, 180);

  handlePhysics();
  renderMap();
  handleTerminals();
  drawHUD();
}

void playChasePhase() {
  background(15, 0, 0);
  ambientLight(20, 0, 0);

  float alarm = (sin(frameCount * 0.1) + 1) * 127;
  pointLight(alarm, 0, 0, cam.position.x, cam.position.y, cam.position.z);

  handlePhysics();
  renderMap();

  float dx = cam.position.x - entityPos.x;
  float dz = cam.position.z - entityPos.z;
  float magSq = dx * dx + dz * dz;
  if (magSq > MIN_DIRECTION_THRESHOLD) {
    float invMag = 1.0 / sqrt(magSq);
    dx *= invMag;
    dz *= invMag;
  }
  entityPos.add(dx * 4.2, 0, dz * 4.2);

  pushMatrix();
  translate(entityPos.x, -100, entityPos.z);
  rotateX(frameCount * 0.2);
  rotateY(frameCount * 0.2);
  fill(0);
  stroke(255, 0, 0);
  strokeWeight(3);
  box(80 + random(ENTITY_JITTER_MIN, ENTITY_JITTER_MAX));
  popMatrix();

  pushMatrix();
  translate(spawnPos.x, -100, spawnPos.z);
  fill(0, 255, 0);
  box(100);
  popMatrix();

  if (dist(cam.position.x, cam.position.z, entityPos.x, entityPos.z) < ENTITY_CAPTURE_DISTANCE) {
    narrativeText = "L'ARCHIVIO TI HA INGHIOTTITO.";
    state = 3;
  }
  if (dist(cam.position.x, cam.position.z, spawnPos.x, spawnPos.z) < ESCAPE_ZONE_RADIUS) {
    narrativeText = "CONNESSIONE INTERROTTA.\nSopravvivenza confermata.";
    state = 3;
  }

  drawHUD();
}

void drawOutro() {
  background(0);
  hint(DISABLE_DEPTH_TEST);
  pushMatrix();
  camera();
  noLights();

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(40);
  text(narrativeText, width/2, height/2);
  textSize(20);
  text("Premi ESC per uscire.", width/2, height/2 + 80);

  popMatrix();
  hint(ENABLE_DEPTH_TEST);
}

void parseMap() {
  for (int z = 0; z < levelMap.length; z++) {
    for (int x = 0; x < levelMap[0].length; x++) {
      if (levelMap[z][x] == 3 && !spawnAssigned) {
        spawnPos = new PVector(x * blockSize + blockSize/2, -100, z * blockSize + blockSize/2);
        cam.position = spawnPos.copy();
        spawnAssigned = true;
      }
      if (levelMap[z][x] == 2) {
        terminals.add(new PVector(x * blockSize + blockSize/2, -50, z * blockSize + blockSize/2));
        levelMap[z][x] = 0;
      }
    }
  }
  if (!spawnAssigned) {
    spawnPos = new PVector(blockSize + blockSize/2, -100, blockSize + blockSize/2);
    cam.position = spawnPos.copy();
    spawnAssigned = true;
  }
  entityPos = new PVector((levelMap[0].length * blockSize) / 2.0, 0, (levelMap.length * blockSize) / 2.0);
}

void handlePhysics() {
  float pR = 40;
  boolean hitX = false;
  boolean hitZ = false;

  if (isWall(cam.position.x + pR, prevPos.z) || isWall(cam.position.x - pR, prevPos.z)) hitX = true;
  if (isWall(prevPos.x, cam.position.z + pR) || isWall(prevPos.x, cam.position.z - pR)) hitZ = true;

  if (hitX) cam.position.x = prevPos.x;
  if (hitZ) cam.position.z = prevPos.z;
  if (isWall(cam.position.x, cam.position.z)) cam.position = prevPos.copy();

  prevPos = cam.position.copy();
}

boolean isWall(float px, float pz) {
  int gridX = constrain(floor(px / blockSize), 0, levelMap[0].length-1);
  int gridZ = constrain(floor(pz / blockSize), 0, levelMap.length-1);
  return levelMap[gridZ][gridX] == 1;
}

void handleTerminals() {
  boolean canInteract = false;

  for (int i = terminals.size() - 1; i >= 0; i--) {
    PVector t = terminals.get(i);

    pushMatrix();
    translate(t.x, -50, t.z);
    fill(50);
    stroke(100);
    strokeWeight(2);
    box(60, 100, 60);
    translate(0, -30, 31);
    fill(0, 255, 0);
    noStroke();
    rect(-20, -15, 40, 30);
    popMatrix();

    float d = dist(cam.position.x, cam.position.z, t.x, t.z);
    if (d < INTERACTION_DISTANCE) {
      canInteract = true;
      hint(DISABLE_DEPTH_TEST);
      pushMatrix();
      camera();
      noLights();
      fill(255);
      textSize(24);
      textAlign(CENTER);
      text("Premi [E] per Riavviare", width/2, height/2 + 50);
      popMatrix();
      hint(ENABLE_DEPTH_TEST);

      if (keyPressed && isInteractKey() && !interactPressed) {
        terminals.remove(i);
        terminalsFixed++;
        updateNarrative();
        interactPressed = true;
      }
      break;
    }
  }

  if (!canInteract || !keyPressed || !isInteractKey()) {
    interactPressed = false;
  }
}

boolean isInteractKey() {
  return key == 'e' || key == 'E';
}

void updateNarrative() {
  if (terminalsFixed == 1) {
    narrativeText = "Terminale 1 Online. Rilevata anomalia nel settore.";
    humTone.setFrequency(45);
    humTone.setWaveform(Waves.SAW);
  } else if (terminalsFixed == 2) {
    narrativeText = "Terminale 2 Online. NON GUARDARE DIETRO DI TE.";
    humTone.setFrequency(35);
  } else if (terminalsFixed == 3) {
    narrativeText = "ERRORE CRITICO. RAGGIUNGI L'USCITA.";
    state = 2;
    humTone.setFrequency(120);
    humTone.setWaveform(Waves.SQUARE);
  }
}

void renderMap() {
  noStroke();
  for (int z = 0; z < levelMap.length; z++) {
    for (int x = 0; x < levelMap[0].length; x++) {
      if (levelMap[z][x] == 1) {
        pushMatrix();
        translate(x * blockSize + blockSize/2, -blockSize/2, z * blockSize + blockSize/2);

        beginShape(QUADS);
        textureMode(NORMAL);
        texture(wallTex);
        vertex(-blockSize/2, -blockSize/2, blockSize/2, 0, 0);
        vertex(-blockSize/2, -blockSize/2, -blockSize/2, 1, 0);
        vertex(-blockSize/2, blockSize/2, -blockSize/2, 1, 1);
        vertex(-blockSize/2, blockSize/2, blockSize/2, 0, 1);
        vertex(blockSize/2, -blockSize/2, -blockSize/2, 0, 0);
        vertex(blockSize/2, -blockSize/2, blockSize/2, 1, 0);
        vertex(blockSize/2, blockSize/2, blockSize/2, 1, 1);
        vertex(blockSize/2, blockSize/2, -blockSize/2, 0, 1);
        vertex(-blockSize/2, -blockSize/2, -blockSize/2, 0, 0);
        vertex(blockSize/2, -blockSize/2, -blockSize/2, 1, 0);
        vertex(blockSize/2, blockSize/2, -blockSize/2, 1, 1);
        vertex(-blockSize/2, blockSize/2, -blockSize/2, 0, 1);
        vertex(blockSize/2, -blockSize/2, blockSize/2, 0, 0);
        vertex(-blockSize/2, -blockSize/2, blockSize/2, 1, 0);
        vertex(-blockSize/2, blockSize/2, blockSize/2, 1, 1);
        vertex(blockSize/2, blockSize/2, blockSize/2, 0, 1);
        endShape();
        popMatrix();
      }
    }
  }

  float mapW = levelMap[0].length * blockSize;
  float mapH = levelMap.length * blockSize;

  pushMatrix();
  translate(mapW/2, 0, mapH/2);

  beginShape(QUADS);
  textureMode(NORMAL);
  texture(floorTex);
  vertex(-mapW/2, 0, -mapH/2, 0, 0);
  vertex(mapW/2, 0, -mapH/2, 20, 0);
  vertex(mapW/2, 0, mapH/2, 20, 20);
  vertex(-mapW/2, 0, mapH/2, 0, 20);
  endShape();

  translate(0, -blockSize, 0);
  beginShape(QUADS);
  textureMode(NORMAL);
  texture(ceilTex);
  vertex(-mapW/2, 0, -mapH/2, 0, 0);
  vertex(mapW/2, 0, -mapH/2, 20, 0);
  vertex(mapW/2, 0, mapH/2, 20, 20);
  vertex(-mapW/2, 0, mapH/2, 0, 20);
  endShape();

  popMatrix();
}

void drawHUD() {
  hint(DISABLE_DEPTH_TEST);
  pushMatrix();
  camera();
  noLights();

  fill(255);
  textSize(24);
  textAlign(CENTER, TOP);
  text(narrativeText, width/2, 20);

  textAlign(LEFT, TOP);
  text("Terminali: " + terminalsFixed + "/" + maxTerminals, 20, 20);

  fill(255, 150);
  noStroke();
  ellipse(width/2, height/2, 4, 4);

  popMatrix();
  hint(ENABLE_DEPTH_TEST);
}

void generateTextures() {
  wallTex = createGraphics(256, 256);
  wallTex.beginDraw();
  wallTex.background(150, 145, 130);
  wallTex.stroke(130, 125, 110);
  for (int i = 0; i < 800; i++) {
    wallTex.point((int)random(256), (int)random(256));
  }
  wallTex.stroke(120, 116, 105);
  for (int y = 0; y < 256; y += 32) {
    wallTex.line(0, y, 256, y);
  }
  wallTex.endDraw();

  floorTex = createGraphics(256, 256);
  floorTex.beginDraw();
  floorTex.background(70, 68, 62);
  floorTex.stroke(80, 78, 72);
  for (int x = 0; x < 256; x += 32) {
    floorTex.line(x, 0, x, 256);
  }
  for (int y = 0; y < 256; y += 32) {
    floorTex.line(0, y, 256, y);
  }
  floorTex.stroke(90, 88, 82, 70);
  for (int i = 0; i < 500; i++) {
    floorTex.point((int)random(256), (int)random(256));
  }
  floorTex.endDraw();

  ceilTex = createGraphics(256, 256);
  ceilTex.beginDraw();
  ceilTex.background(210, 210, 200);
  ceilTex.noStroke();
  for (int i = 0; i < 40; i++) {
    float x = random(30, 226);
    float y = random(30, 226);
    ceilTex.fill(235, 235, 220, 210);
    ceilTex.rect(x - 12, y - 12, 24, 24);
  }
  ceilTex.stroke(190, 190, 180, 90);
  for (int y = 0; y < 256; y += 16) {
    ceilTex.line(0, y, 256, y);
  }
  ceilTex.endDraw();
}
