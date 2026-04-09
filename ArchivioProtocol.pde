import queasycam.*;
import ddf.minim.*;
import ddf.minim.ugens.*;

QueasyCam cam;
Minim minim;
AudioOutput out;
Oscil hum;

int state = 0; // 0 intro, 1 game, 2 win, 3 lose
int block = 220;
int W = 20, H = 20;
int[][] map = new int[H][W]; // 0 floor,1 wall,2 exit locked
PVector spawn, exitPos;
boolean exitUnlocked = false;
int fuses = 0;
int needFuses = 3;

PVector enemy;
String msg = "Trova 3 fusibili";

void setup() {
  fullScreen(P3D);
  noCursor();
  frameRate(60);

  minim = new Minim(this);
  out = minim.getLineOut();
  hum = new Oscil(45, 0.08, Waves.SAW);
  hum.patch(out);

  cam = new QueasyCam(this);
  cam.speed = 4.0;
  cam.sensitivity = 0.55;

  genMap();
  cam.position = spawn.copy();
  enemy = new PVector((W-3)*block + block/2, 0, (H-3)*block + block/2);
}

void draw() {
  if (state == 0) drawIntro();
  else if (state == 1) runGame();
  else drawEnd();
}

void drawIntro() {
  background(0);
  hint(DISABLE_DEPTH_TEST);
  camera();
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(40);
  text("ARCHIVE PROTOCOL", width/2, height/2 - 80);
  textSize(22);
  text("WASD muovi, mouse guarda, E interagisci\nPremi SPAZIO per iniziare", width/2, height/2);
  hint(ENABLE_DEPTH_TEST);

  if (keyPressed && key == ' ') state = 1;
}

void runGame() {
  background(150, 145, 130);
  ambientLight(150, 145, 130);

  renderMap();
  doCollision();
  updateEnemy();
  drawHUD();

  if (dist(cam.position.x, cam.position.z, enemy.x, enemy.z) < 100) {
    msg = "TI HA PRESO";
    state = 3;
  }
  if (exitUnlocked && dist(cam.position.x, cam.position.z, exitPos.x, exitPos.z) < 140) {
    msg = "SEI SCAPPATO";
    state = 2;
  }
}

void drawEnd() {
  background(0);
  hint(DISABLE_DEPTH_TEST);
  camera();
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(42);
  text(msg, width/2, height/2);
  textSize(20);
  text("ESC per uscire", width/2, height/2 + 70);
  hint(ENABLE_DEPTH_TEST);
}

void genMap() {
  for (int z=0; z<H; z++) for (int x=0; x<W; x++) map[z][x] = 1;

  for (int z=1; z<H-1; z++) for (int x=1; x<W-1; x++) map[z][x] = 0;

  // muri interni
  for (int z=2; z<18; z++) map[z][6] = 1;
  for (int z=3; z<17; z++) map[z][13] = 1;
  for (int x=2; x<18; x++) map[8][x] = 1;
  for (int x=2; x<18; x++) map[14][x] = 1;

  // passaggi
  map[5][6]=0; map[11][6]=0; map[16][6]=0;
  map[4][13]=0; map[10][13]=0; map[15][13]=0;
  map[8][4]=0; map[8][10]=0; map[8][16]=0;
  map[14][5]=0; map[14][12]=0; map[14][17]=0;

  spawn = new PVector(2*block + block/2, 0, 2*block + block/2);
  exitPos = new PVector(10*block + block/2, 0, 1*block + block/2);
  map[1][10] = 2; // exit locked
}

void renderMap() {
  noStroke();

  for (int z=0; z<H; z++) {
    for (int x=0; x<W; x++) {
      float wx = x*block + block/2;
      float wz = z*block + block/2;

      // floor
      pushMatrix();
      translate(wx, 0, wz);
      fill(60 + ((x+z)%2)*5);
      box(block, 6, block);
      popMatrix();

      // ceiling
      pushMatrix();
      translate(wx, -block, wz);
      fill(95);
      box(block, 6, block);
      popMatrix();

      if (map[z][x] == 1) {
        pushMatrix();
        translate(wx, -block/2, wz);
        fill(130, 120, 100);
        box(block, block, block);
        popMatrix();
      }

      if (map[z][x] == 2) {
        pushMatrix();
        translate(wx, -100, wz);
        fill(exitUnlocked ? color(50, 180, 60) : color(140, 40, 40));
        box(block*0.8, 200, 40);
        popMatrix();
      }
    }
  }

  // 3 "fusibili" fake come cubi da raccogliere: aree trigger
  drawFuseSpot(3, 5);
  drawFuseSpot(16, 4);
  drawFuseSpot(17, 16);
}

void drawFuseSpot(int gx, int gz) {
  float wx = gx*block + block/2;
  float wz = gz*block + block/2;
  pushMatrix();
  translate(wx, -30 + sin(frameCount*0.08)*5, wz);
  fill(220, 180, 80);
  box(30);
  popMatrix();

  if (dist(cam.position.x, cam.position.z, wx, wz) < 120) {
    hint(DISABLE_DEPTH_TEST);
    camera();
    fill(255);
    textAlign(CENTER, CENTER);
    text("Premi E per raccogliere", width/2, height/2 + 50);
    hint(ENABLE_DEPTH_TEST);

    if (keyPressed && (key=='e' || key=='E')) {
      // disattiva spot mettendo coordinate fuori mappa
      if (gx==3 && gz==5) { gx=999; gz=999; }
      fuses = min(needFuses, fuses+1);
      if (fuses >= needFuses) {
        exitUnlocked = true;
        msg = "Uscita sbloccata";
      }
    }
  }
}

void doCollision() {
  float r = 40;
  int gx = constrain(floor(cam.position.x / block), 0, W-1);
  int gz = constrain(floor(cam.position.z / block), 0, H-1);

  if (map[gz][gx] == 1 || (map[gz][gx] == 2 && !exitUnlocked)) {
    // reset soft verso spawn (semplice ma evita pass-through totale)
    cam.position.x = lerp(cam.position.x, spawn.x, 0.15);
    cam.position.z = lerp(cam.position.z, spawn.z, 0.15);
  }

  // clamp mondo
  cam.position.x = constrain(cam.position.x, block, (W-1)*block);
  cam.position.z = constrain(cam.position.z, block, (H-1)*block);
}

void updateEnemy() {
  PVector d = PVector.sub(new PVector(cam.position.x, 0, cam.position.z), enemy);
  d.normalize();
  d.mult(2.6);
  enemy.add(d);

  pushMatrix();
  translate(enemy.x, -90, enemy.z);
  rotateY(frameCount*0.07);
  fill(0);
  stroke(255, 0, 0);
  box(70, 170, 50);
  popMatrix();
}

void drawHUD() {
  hint(DISABLE_DEPTH_TEST);
  camera();
  fill(255);
  textAlign(LEFT, TOP);
  textSize(20);
  text("Fusibili: " + fuses + "/" + needFuses, 20, 20);
  text(msg, 20, 50);

  fill(255, 150);
  ellipse(width/2, height/2, 4, 4);
  hint(ENABLE_DEPTH_TEST);
}
