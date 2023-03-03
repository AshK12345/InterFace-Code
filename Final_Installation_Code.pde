import processing.serial.*;
import cc.arduino.*;

Arduino arduino;
Arduino arduinoStepPad;

// ANALOG PINS
int rPotPin = 0; // pot for color R
int gPotPin = 1; // pot for color G
int bPotPin = 2; // pot for color B
int strokeSliderPin = 3;
int opacityFlexPin = 4;
int rotatePotPin = 5;

// DIGITAL PINS (tested on arduino side)
int checkmarkButtonPin = 5;
int xReflButtonPin = 6;
int yReflButtonPin = 7;
int curveButtonPin = 8;

// ANALOG PINS (on other arduino)
int leftSensorPin = 0;
int rightSensorPin = 1;
int upSensorPin = 2;
int downSensorPin = 3;

// For Buttons
int xReflPrevButtonVal = 0;
int yReflPrevButtonVal = 0;
int checkmarkPrevButtonVal = 0;

// Initial Boolean Values
boolean left = false;
boolean right = false;
boolean up = false;
boolean down = false;
boolean checkmarkButtonAction = false;
boolean xReflAction = false;
boolean yReflAction = false;

// Force sensor Step Pad Thresholds
int leftThreshold = 0;
int rightThreshold = 0;
int upThreshold = 0;
int downThreshold = 0;

// Color Mapping Ranges
int rPotMin = 0;
int rPotMax = 1023;

int gPotMin = 0;
int gPotMax = 1023;

int bPotMin = 0;
int bPotMax = 1023;

int colorMin = 0;
int colorMax = 255;

// Slider Mapping Ranges (for Stroke)
int sliderMin = 0;
int sliderMax = 1023;
int strokeMin = 0;
int strokeMax = 50;

// Opacity Mapping Ranges
int opacityFlexMin = 0;
int opacityFlexMax = 1023;
int tintMin = 0;
int tintMax = 100;

// Rotation Mapping Ranges
int rotatePotMin = 0;
int rotatePotMax = 1023;
int rotValMin = 0;
int rotValMax = 360;

//Curve Button
int curveButtonVal = 0;


PGraphics[] art= new PGraphics[100]; ////Creating 100 blank PGraphics objects to act as layers (100 was chosen to ensure that users could never feasibly blow past the number of possible layers for interaction, while also maintaining computational efficiency)
int layerCount=0; //This variable stores the value of the active layer that Processing draws on. Initially, it is 0.

//The four following variables store location data for the visualization. oldPtX and oldPtY are the last registered coordinates of a previous point, while their new counterparts are the next coordinates of the following point (which users dynamically set through physical controls)
float oldPtX=0;
float oldPtY=0;
float newPtX=0;
float newPtY=0;

//The following 8 values represent aesthetic controls for the user to manipulate for their visualization.
int rVal; //red control
int bVal; //blue control
int gVal; //green control
int strokeSize=4; //stroke size control
int tintVal=255; //opacity control
float rotVal=0; //rotation control

float[] cntrlPts = new float[4]; //This variable stores the four control point values (two x-y coordinates for two points) needed in Processing to draw a curve. These points are meant to be randomized by both the prgram and the user upon each new line drawn

boolean[] reflectState= new boolean[100]; //This state variable stores wheter or not a specific layer has a reflection utilized within it's transformations. This allows user to change the number of reflections they utilize between layers (i.e. layer 2 had only a relfection along the x-axis, whiel layer 5 has a reflection along both x and y)

int counter=0; //This variable is a state variable used in debugging

int reflectCount=0; //number of reflections control (this is a debugging state value, it only goes up to a maximum of three)

void setupArduino() { //The following function Intializes two Arduino objects (You need at least two Unos for all of the inputs used). It also sets the pinmodes for our inputs
  arduino = new Arduino(this, Arduino.list()[3], 57600);
  arduinoStepPad = new Arduino(this, Arduino.list()[2], 57600);


  arduino.pinMode(strokeSliderPin, Arduino.INPUT);
  arduino.pinMode(checkmarkButtonPin, Arduino.INPUT);
  arduino.pinMode(xReflButtonPin, Arduino.INPUT);
  arduino.pinMode(yReflButtonPin, Arduino.INPUT);
  arduino.pinMode(opacityFlexPin, Arduino.INPUT);
  arduino.pinMode(rotatePotPin, Arduino.INPUT);
}

void readInput() { //reads all inputs for updated values

  // MOVE LEFT (force pads)
  int leftSensor = arduinoStepPad.analogRead(leftSensorPin);
  left = leftSensor > leftThreshold;

  // MOVE RIGHT (force pads)
  int rightSensor = arduinoStepPad.analogRead(rightSensorPin);
  right = rightSensor > rightThreshold;

  // MOVE UP (force pads)
  int upSensor = arduinoStepPad.analogRead(upSensorPin);
  up = upSensor > upThreshold;

  // MOVE DOWN (force pads)
  int downSensor = arduinoStepPad.analogRead(downSensorPin);
  down = downSensor > downThreshold;

  // ADJUST R COLOR VALUE (Potentiometer)
  // range 0-255
  int rPot = arduino.analogRead(rPotPin);
  rVal = int(map(rPot, rPotMin, rPotMax, colorMin, colorMax));
  println("r: ", rVal);
  println("rP: ", rPot);

  // ADJUST G COLOR VALUE (Potentiometer)
  // range 0-255
  int gPot = arduino.analogRead(gPotPin);
  gVal = int(map(gPot, gPotMin, gPotMax, colorMin, colorMax));
  println("g: ", gVal);
  println("gP: ", gPot);

  // ADJUST B COLOR VALUE (Potentiometer)
  // range 0-255
  int bPot = arduino.analogRead(bPotPin);
  bVal = int(map(bPot, bPotMin, bPotMax, colorMin, colorMax));
  println("b: ", bVal);
  println("bP: ", bPot);

  //// STROKE SIZE (Slider)
  int strokeSlider = arduino.analogRead(strokeSliderPin);
  strokeSize = int(map(strokeSlider, sliderMin, sliderMax, strokeMin, strokeMax));
  //println("stroke: ", strokeSize);

  // CHECKMARK BUTTON (on ceiling)
  // CHECK IF BUTTON PRESSED (program this as a latch high then low)
  int checkmarkButton = arduino.digitalRead(checkmarkButtonPin);
  checkmarkButtonAction = checkmarkPrevButtonVal == 1 && checkmarkButton == 0;
  //println("checkmark: ", checkmarkButtonAction);
  checkmarkPrevButtonVal = checkmarkButton;

  // REFLECTION
  // 2 INPUTS -- X and Y Reflection (buttons)
  int xReflButton = arduino.digitalRead(xReflButtonPin);
  xReflAction = xReflPrevButtonVal == 1 && xReflButton == 0;
  //println("xrefl: ", xReflAction);
  xReflPrevButtonVal = xReflButton;

  int yReflButton = arduino.digitalRead(yReflButtonPin);
  yReflAction = yReflPrevButtonVal == 1 && yReflButton == 0;
  //println("yrefl: ", yReflAction);
  yReflPrevButtonVal = yReflButton;

  // OPACTIY -- Pulley
  int opacityFlex = arduino.analogRead(opacityFlexPin);
  tintVal = int(map(opacityFlex, opacityFlexMin, opacityFlexMax, tintMin, tintMax));

  // Rotation -- Wheel (Potentiometer)
  // Scale it to 360
  int rotatePot = arduino.analogRead(rotatePotPin);
  rotVal = int(map(rotatePot, rotatePotMin, rotatePotMax, rotValMin, rotValMax));

  //Change Control Points with Curve Button
  curveButtonVal = arduino.digitalRead(curveButtonPin);
}

void setup() {
  size(1000, 1000, P3D);
  for (int i=0; i<100; i++) { //This loop initializes the 100 PGraphics objects we use as layers, and then turns them on and off so that Processing allocates memory for them so that we can call any of them in the future with no errors
    art[i] = createGraphics(1000, 1000, P3D);
    art[i].beginDraw();
    art[i].endDraw();
  }

  setupArduino(); //setup Arduino function call
}

//The following function changes the parameters of the current curve on the active layer
void drawWithInput() {
  //The following if-else structure creates reflected projections of the "original curve" - as in, the base curve that is later reflected by the following if-else structure. If no refelction input is registered, the if-else is skipped and the following code runs immediately
  //NOTE: every time a reflection state is engaged by the user through physical input, Processing begins drawing the proceeding curves on the next layer, one value higher. This is so the reflections engaged can be turned off/change states without affecting the reflections utilized earlier, thereby creating a discrete state system to recognize the reflections
  if (yReflAction && xReflAction) { //This if statement draws the original curve, plus an x and y reflected curve if the use provides physical input that suggests to draw both
    layerCount++; //moves user to next layer to draw the curves, since a new layer must be accessed every time a new form of reflection is engaged

    //the following section of code draws the acctive layer as an image, and also draws both an x-reflection and y-reflection of that image on top of the original
    pushMatrix();
    scale(-1, 1);
    image(art[layerCount], 0, 0);
    popMatrix();
    pushMatrix();
    scale(1, -1);
    image(art[layerCount], 0, 0);
    popMatrix();
    pushMatrix();
    scale(-1, -1);
    image(art[layerCount], 0, 0);
    popMatrix();

    //the following section performs all of the curve form manipulations on both the x and y reflected curves (NOTE: These manipulations are being applied to the CURVES THEMSELVES, not the dynamically-updated image of the curves that is displayed to the users
    pushMatrix();
    scale(-1, 1);
    rotate(rotVal);
    fill(255);
    stroke(0);
    ellipse(newPtX, newPtY, 20, 20);
    popMatrix();
    pushMatrix();
    scale(-1, 1);
    rotate(rotVal);
    beginShape();
    noFill();
    stroke(rVal, gVal, bVal);
    strokeWeight(strokeSize);
    vertex(oldPtX, oldPtY);
    bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    endShape();
    popMatrix();

    pushMatrix();
    scale(1, -1);
    rotate(rotVal);
    fill(255);
    stroke(0);
    ellipse(newPtX, newPtY, 20, 20);
    popMatrix();
    pushMatrix();
    scale(1, -1);
    rotate(rotVal);
    beginShape();
    noFill();
    stroke(rVal, gVal, bVal);
    strokeWeight(strokeSize);
    vertex(oldPtX, oldPtY);
    bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    endShape();
    popMatrix();

    pushMatrix();
    scale(-1, -1);
    rotate(rotVal);
    fill(255);
    stroke(0);
    ellipse(newPtX, newPtY, 20, 20);
    popMatrix();
    pushMatrix();
    scale(-1, -1);
    rotate(rotVal);
    beginShape();
    noFill();
    stroke(rVal, gVal, bVal);
    strokeWeight(strokeSize);
    vertex(oldPtX, oldPtY);
    bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    endShape();
    popMatrix();
  } else if (yReflAction) { //This else if performs the same function as the previous if, but only provides a y-axis reflection
    layerCount++;
    pushMatrix();
    scale(-1, 1);
    image(art[layerCount], 0, 0);
    popMatrix();

    pushMatrix();
    scale(-1, 1);
    rotate(rotVal);
    fill(255);
    stroke(0);
    ellipse(newPtX, newPtY, 20, 20);
    popMatrix();
    pushMatrix();
    scale(-1, 1);
    rotate(rotVal);
    beginShape();
    noFill();
    stroke(rVal, gVal, bVal);
    strokeWeight(strokeSize);
    vertex(oldPtX, oldPtY);
    bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    endShape();
    popMatrix();
  } else if (xReflAction) { //This else if performs the same function as the previous if, but only provides a x-axis reflection

    layerCount++;
    pushMatrix();
    scale(1, -1);
    image(art[layerCount], 0, 0);
    popMatrix();


    pushMatrix();
    scale(1, -1);
    rotate(rotVal);
    fill(255);
    stroke(0);
    ellipse(newPtX, newPtY, 20, 20);
    popMatrix();
    pushMatrix();
    scale(1, -1);
    rotate(rotVal);
    beginShape();
    noFill();
    stroke(rVal, gVal, bVal);
    strokeWeight(strokeSize);
    vertex(oldPtX, oldPtY);
    bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    endShape();
    popMatrix();
  }

  //The following section draws the "original curve", but it does not set it onto the layer  it just creates a dynamically-updating curve that is not locked onto the active layer yet
  pushMatrix();
  rotate(rotVal);
  fill(255);
  stroke(0);
  ellipse(newPtX, newPtY, 20, 20);
  popMatrix();
  pushMatrix();
  rotate(rotVal);
  beginShape();
  noFill();
  stroke(rVal, gVal, bVal);
  strokeWeight(strokeSize);
  vertex(oldPtX, oldPtY);
  bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
  endShape();
  popMatrix();

  //the following if statements change the position of the end point on the active curve
  if (left) {
    newPtX=newPtX-5*cos(rotVal);
    newPtY=newPtY-5*sin(-rotVal);
  }

  if (right) {
    newPtX=newPtX+5*cos(rotVal);
    newPtY=newPtY+5*sin(-rotVal);
  }

  if (down) {
    newPtX=newPtX+5*sin(rotVal);
    newPtY=newPtY+5*cos(rotVal);
  }

  if (up) {
    newPtX=newPtX-5*sin(rotVal);
    newPtY=newPtY-5*cos(rotVal);
  }

  if (checkmarkButtonAction) { //The following code locks the currently-being-drawn curve onto the active layer, thereby "ending" that curve and "beginning" the next one
    art[layerCount].smooth();
    art[layerCount].beginDraw();
    art[layerCount].translate(500, 500);
    art[layerCount].noFill();
    art[layerCount].stroke(rVal, gVal, bVal);
    art[layerCount].strokeWeight(strokeSize);
    art[layerCount].rotate(rotVal);
    art[layerCount].beginShape();
    art[layerCount].vertex(oldPtX, oldPtY);
    art[layerCount].bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    art[layerCount].endShape();

    //The following code locks the currently-being-drawn refelctions of the original curve onto the active layer, thereby "ending" those reflected curves and "beginning" the next ones
    if (yReflAction && !xReflAction) {
      art[layerCount].beginShape();
      art[layerCount].vertex(-oldPtX, oldPtY);
      art[layerCount].bezierVertex(-cntrlPts[0], cntrlPts[1], -cntrlPts[2], cntrlPts[3], -newPtX, newPtY);
      art[layerCount].endShape();
    }

    if (!yReflAction && xReflAction) {
      art[layerCount].beginShape();
      art[layerCount].vertex(oldPtX, -oldPtY);
      art[layerCount].bezierVertex(cntrlPts[0], -cntrlPts[1], cntrlPts[2], -cntrlPts[3], newPtX, -newPtY);
      art[layerCount].endShape();
    }


    if (yReflAction && xReflAction) {
      art[layerCount].beginShape();
      art[layerCount].vertex(-oldPtX, -oldPtY);
      art[layerCount].bezierVertex(-cntrlPts[0], -cntrlPts[1], -cntrlPts[2], -cntrlPts[3], -newPtX, -newPtY);
      art[layerCount].endShape();
    }

    art[layerCount].endDraw();

    //the following code changes the point vaues for the curves being drawn post-lock – basically, once the user has locked the previous curve onto the layer, the values of the next curve update such that the endpoint of the previous curve become the starting point of the next curve, and the control points for the next curve are completely randomized
    oldPtX=newPtX;
    oldPtY=newPtY;

    cntrlPts[0]=random(-500, 500);
    cntrlPts[1]=random(-500, 500);
    cntrlPts[2]=random(-500, 500);
    cntrlPts[3]=random(-500, 500);
  }
}

//The following section is a debugging function where every parameter can be controlled via a keyboard - only use this function if you need to debug or test interactions
void drawKeyboard() {
  switch(reflectCount) {
  case 1:

    pushMatrix();
    scale(-1, 1);
    image(art[layerCount], 0, 0);
    popMatrix();

    pushMatrix();
    scale(-1, 1);
    rotate(rotVal);
    fill(255);
    stroke(0);
    ellipse(newPtX, newPtY, 20, 20);
    popMatrix();
    pushMatrix();
    scale(-1, 1);
    rotate(rotVal);
    beginShape();
    noFill();
    stroke(rVal, gVal, bVal);
    strokeWeight(strokeSize);
    vertex(oldPtX, oldPtY);
    bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    endShape();
    popMatrix();


    break;
  case 2:

    pushMatrix();
    scale(1, -1);
    image(art[layerCount], 0, 0);
    popMatrix();



    pushMatrix();
    scale(1, -1);
    rotate(rotVal);
    fill(255);
    stroke(0);
    ellipse(newPtX, newPtY, 20, 20);
    popMatrix();
    pushMatrix();
    scale(1, -1);
    rotate(rotVal);
    beginShape();
    noFill();
    stroke(rVal, gVal, bVal);
    strokeWeight(strokeSize);
    vertex(oldPtX, oldPtY);
    bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    endShape();
    popMatrix();

    break;


  case 3:
    pushMatrix();
    scale(-1, 1);
    image(art[layerCount], 0, 0);
    popMatrix();
    pushMatrix();
    scale(1, -1);
    image(art[layerCount], 0, 0);
    popMatrix();
    pushMatrix();
    scale(-1, -1);
    image(art[layerCount], 0, 0);
    popMatrix();

    pushMatrix();
    scale(-1, 1);
    rotate(rotVal);
    fill(255);
    stroke(0);
    ellipse(newPtX, newPtY, 20, 20);
    popMatrix();
    pushMatrix();
    scale(-1, 1);
    rotate(rotVal);
    beginShape();
    noFill();
    stroke(rVal, gVal, bVal);
    strokeWeight(strokeSize);
    vertex(oldPtX, oldPtY);
    bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    endShape();
    popMatrix();

    pushMatrix();
    scale(1, -1);
    rotate(rotVal);
    fill(255);
    stroke(0);
    ellipse(newPtX, newPtY, 20, 20);
    popMatrix();
    pushMatrix();
    scale(1, -1);
    rotate(rotVal);
    beginShape();
    noFill();
    stroke(rVal, gVal, bVal);
    strokeWeight(strokeSize);
    vertex(oldPtX, oldPtY);
    bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    endShape();
    popMatrix();

    pushMatrix();
    scale(-1, -1);
    rotate(rotVal);
    fill(255);
    stroke(0);
    ellipse(newPtX, newPtY, 20, 20);
    popMatrix();
    pushMatrix();
    scale(-1, -1);
    rotate(rotVal);
    beginShape();
    noFill();
    stroke(rVal, gVal, bVal);
    strokeWeight(strokeSize);
    vertex(oldPtX, oldPtY);
    bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
    endShape();
    popMatrix();

    reflectCount=0;
    break;
  }

  pushMatrix();
  rotate(rotVal);
  fill(255);
  stroke(0);
  ellipse(newPtX, newPtY, 20, 20);
  popMatrix();
  pushMatrix();
  rotate(rotVal);
  beginShape();
  noFill();
  stroke(rVal, gVal, bVal);
  strokeWeight(strokeSize);
  vertex(oldPtX, oldPtY);
  bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
  endShape();
  popMatrix();

  if (keyPressed==true) {

    if (key=='a') {
      newPtX=newPtX-5*cos(rotVal);
      newPtY=newPtY-5*sin(-rotVal);
    }

    if (key=='d') {
      newPtX=newPtX+5*cos(rotVal);
      newPtY=newPtY+5*sin(-rotVal);
    }

    if (key=='s') {
      newPtX=newPtX+5*sin(rotVal);
      newPtY=newPtY+5*cos(rotVal);
    }

    if (key=='w') {
      newPtX=newPtX-5*sin(rotVal);
      newPtY=newPtY-5*cos(rotVal);
    }

    if (key=='r') {
      rVal=rVal+5;
    }

    if (key=='g') {
      gVal=gVal+5;
    }

    if (key=='b') {
      bVal=bVal+5;
    }

    if (key=='t') {
      strokeSize++;
    }

    if (key=='j') {

      if (counter==0) {
        art[layerCount].smooth();
        art[layerCount].beginDraw();
        art[layerCount].translate(500, 500);
        art[layerCount].noFill();
        art[layerCount].stroke(rVal, gVal, bVal);
        art[layerCount].strokeWeight(strokeSize);
        art[layerCount].rotate(rotVal);
        art[layerCount].beginShape();
        art[layerCount].vertex(oldPtX, oldPtY);
        art[layerCount].bezierVertex(cntrlPts[0], cntrlPts[1], cntrlPts[2], cntrlPts[3], newPtX, newPtY);
        art[layerCount].endShape();

        if (reflectCount==1) {
          art[layerCount].beginShape();
          art[layerCount].vertex(-oldPtX, oldPtY);
          art[layerCount].bezierVertex(-cntrlPts[0], cntrlPts[1], -cntrlPts[2], cntrlPts[3], -newPtX, newPtY);
          art[layerCount].endShape();
        }

        if (reflectCount==2) {
          art[layerCount].beginShape();
          art[layerCount].vertex(oldPtX, -oldPtY);
          art[layerCount].bezierVertex(cntrlPts[0], -cntrlPts[1], cntrlPts[2], -cntrlPts[3], newPtX, -newPtY);
          art[layerCount].endShape();
        }


        if (reflectCount==3) { //wont need this once button is connected, just for demo rn
          art[layerCount].beginShape();
          art[layerCount].vertex(-oldPtX, -oldPtY);
          art[layerCount].bezierVertex(-cntrlPts[0], -cntrlPts[1], -cntrlPts[2], -cntrlPts[3], -newPtX, -newPtY);
          art[layerCount].endShape();
          art[layerCount].endDraw();
        }

        art[layerCount].endDraw();
        oldPtX=newPtX;
        oldPtY=newPtY;
        counter++;
      }
    }
    if (key=='f') {
      counter=0;
      cntrlPts[0]=random(-500, 500);
      cntrlPts[1]=random(-500, 500);
      cntrlPts[2]=random(-500, 500);
      cntrlPts[3]=random(-500, 500);
    }
    if (key=='y') {
      layerCount++;
      reflectCount++;
    }
    if (key=='v') {
      tintVal=tintVal-1;
    }
    if (key=='p') {
      rotVal++;
    }
    if (key=='m') {
      layerCount++;
    }
  }
}

void draw() {
  //The following code sets up the visualization window
  translate(500, 500); //Centers the origin to the center of the visualization screen
  background(0); //Sets background to black
  imageMode(CENTER); //Centers the various layers
  tint(255, tintVal); //Sets the default opacity to max

  //The following for loop calls all 100 layers as images that are stacked on top of one another, witht heir cneter being at the center of the visualization screen window. The idea here is that whena user leaves one layer and jumps tot he next by finishing one curve and starting another, the previous laers cannot be manipulated by future user manipulations because they are being called as images on every iteration of this code. Therefore, only the active layer will be able to be changed when a user manipulates the physical interactions.
  //For example, let's say the user is drawing a curve on layer 6. When the user sets that curve on the visualization by hitting the "confrim" button, Processing imemdiately moves the user to layer 7, and layers 0 through 6 become locked and unchangeable. When this code iterates, it draws every layer on the viewing screen as an image, meaning only the layer that is active (layer 7, in this example) and being dynamically altered by the user will change on the visualization (thereby meaning that only the line or curve that the user is drawing at any given moment is what they are able to alter).
  //Even though it visually appears that the user is drawing a continuation of their previously drawn curve, they are in actuality drawing a new curve on a new layer, who's starting point is at the ending point of the previous curve on the last layer.
  for (int i=0; i<=99; i++) {
    image(art[i], 0, 0);
  }

  // For reading values from Arduino sensors
  readInput();

  // Either with sensors
  drawWithInput();

  // Or with keyboard input
  drawKeyboard();
}
