int dataNum = 500; //number of data to show
int rawData = 0; //raw data from serial port
int rawData2=0;

float[] sensorHist = new float[dataNum]; //history data to show

int beatData = 0; //raw data from serial port
float[] beatHist = new float[dataNum]; //history data to show

boolean beatDetected = false;

int ts = 0; //global timestamp (updated by the incoming data)
float[] IBIHist   = new float[dataNum];  //history interbeat intervals (IBI)
int currIBI = 0;
int lastBeatTime = 0;

ArrayList<Float> IBIList;
int maxFileSize = 1000;
int lastCapture = 0;


ArrayList<Float> HRList;
float currHR = 0;

//All the variables etc. used for the sinus/cosinus lines
float scale = 4;   // the scale creates a grid within the screen, this helps with the speed of the program by decreasing resolution.
int f=floor(1020/scale);
float si[] =  new float[f];
float co[] =  new float[f];
float amplitude;

//Variables used for the sound visualisation
float heart;
float saturation;
float wave=0;
int pos;
boolean bDrawOnly = false;


import processing.serial.*;
Serial port; 
//functions which create the outline for the lines depicted
float sinus(int i, float b, float c) {
    return b*sin(i/(2*PI)-c*PI/10);
  }
float cosin(int i, float b, float c)
  {
    return b*cos(i/(2*PI)+0.5*PI+c*PI/9);
  }


void setup()
{
  size(1000, 500);

  for (int i = 0; i < Serial.list().length; i++) println("[", i, "]:", Serial.list()[i]);
  String portName = Serial.list()[Serial.list().length-1];//check the printed list
  //String portName = Serial.list()[0]; //For windows PC
  port = new Serial(this, "COM5", 115200);
  port.bufferUntil('\n'); // arduino ends each data packet with a carriage return 
  port.clear();           // flush the Serial buffer
 IBIList = new ArrayList<Float>();
  HRList = new ArrayList<Float>();

}

int HR_WINDOW = 10;
float[] dataIBI = new float[HR_WINDOW];

void initHR() {
  dataIBI = new float[HR_WINDOW]; 
}

float nextValueHR(float val) {
  float totalIBI = 0;
  appendArray(dataIBI, val);
  for(int i = 0 ; i < dataIBI.length; i++){
    totalIBI += dataIBI[i];
  }
  return 60000./(totalIBI/(float)HR_WINDOW);
}


void draw() {
    float h = height/4;

  float heart = map(rawData, 0, 1023, 0, height);
background(0, 166, 206);
  
  
  //This part draws the sinus/cosinus waves
  pushMatrix();
  for (int i=0; i<f; i++)
  { 
    //this increases the amplitude of the waves towards the center and decreases it again from the center to the end.
    //It also changes the amplitude according to the volume for example if the volume is 0 the amplitude is 0 but if the volume is high you will have high peaks in the lines.
    if (2*i<=f)
    {
      amplitude=500*2*i/f*(heart/1000);
    } else if (2*i>f)
    {
      amplitude=500*2*(f-i)/f*(heart/1000);
    }

    pos=floor(map(i, 0, heart, 0, f));

    //fill the array with all the y coordinates of the waves
    si[i]=sinus(i, amplitude, wave)+saturation;
    co[i]=cosin(i, amplitude, wave)+saturation;
  }

  translate(0, height/2); //translate the center vertically to the middle.
  stroke(255,180,180); //white stroke

  //This actually draws the lines
  for (int i=1; i<f; i++)
  {
    //use the same method as increasing amplitude towards the center of the screen to increase strokeweight
    if (2*i<=f)
    {
      amplitude=500*2*i/f*(heart/20);
    } else if (2*i>f)
    {
      amplitude=500*2*(f-i)/f*(heart/20);
    }
    strokeWeight(5*heart/200);

    //draw the lines from the previous pooint to the next.
    line((i-1)*scale, si[i-1], i*scale, si[i]);
    line((i-1)*scale, co[i-1], i*scale, co[i]);
  }
  wave++; //this makes the waves move from side to side
  popMatrix();
  
   int visLength = min(IBIList.size(), HRList.size());


  if (HRList!=null) { //to avoid concurrent modification
    float lastX = 0;
    float lastY = 0;
    for (int i = 0; i < visLength; i++) {
      float ibi = IBIList.get(i);
      float hr = HRList.get(i);
      float x = map(ibi, 0, 60000*scale, 0, width); //60000ms = 1 min;
      float y = map(hr, 0, 120, 0, h);
      stroke(0, 255, 255);
      line(lastX, 4*h, lastX, 4*h-y); 
      lastX+=x;
      lastY=y;
    }
  }
  
if (HRList.size()<10) {text("Calculating Heart Rate:"+HRList.size()+"/"+HR_WINDOW, 0, 3.1*h);}
    else {text("Heart Rate: "+nf(currHR, 0, 1)+" bpm", 0, 3.1*h);}
}


void serialEvent(Serial port) {   
  String inData = port.readStringUntil('\n');  // read the serial string until seeing a carriage return
  int dataIndex = -1;
  if (inData.charAt(0) == 'A') {  
    dataIndex = 0;
  }
  if (inData.charAt(0) == 'B') {  
    dataIndex = 1;
  }
  //data processing
  if (dataIndex==0) {
    rawData = int(trim(inData.substring(1))); //store the value
    appendArray(sensorHist, rawData); //store the data to history (for visualization)
    ts+=2; //update the timestamp
    return;
  }
  if (dataIndex==1) {
    beatData = int(trim(inData.substring(1))); //store the value
    if (!beatDetected) {
      if (beatData==1) { 
        beatDetected = true; 
        appendArray(beatHist, 1); //store the data to history (for visualization)
        if (lastBeatTime>0) {
          currIBI = ts-lastBeatTime;
          if (IBIList.size() < maxFileSize) { 
            IBIList.add((float)currIBI); //add the currIBI to the IBIList
            currHR = nextValueHR((float)currIBI);
            if (HRList.size()<HR_WINDOW) {
              HRList.add((float)0);
            } else {
              HRList.add(currHR);
            }
          }
        } 
        lastBeatTime = ts;
      } else {
        appendArray(beatHist, 0); //store the data to history (for visualization)
      }
    } else {
      if (beatData==0) beatDetected = false;
      appendArray(beatHist, 0); //store the data to history (for visualization)
    }
    appendArray(IBIHist, currIBI); //store the data to history (for visualization)
    return;
  }
}

//Append a value to a float[] array.
float[] appendArray (float[] _array, float _val) {
  float[] array = _array;
  float[] tempArray = new float[_array.length-1];
  arrayCopy(array, 1, tempArray, 0, tempArray.length);
  array[array.length-1] = _val;
  arrayCopy(tempArray, 0, array, 0, tempArray.length);
  return array;
}