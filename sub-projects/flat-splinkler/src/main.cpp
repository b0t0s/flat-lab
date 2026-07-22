#include <Arduino.h>
#include "DHT.h"

#define RedPin 3
#define BluePin 5
#define GreenPin 6

#define MachineRedpin 9 // active for disabled machine
#define MachineGreenpin 10 // pin for active machine

#define DHT22_PIN 7
#define DHTTYPE DHT22
#define MOISTURE_PIN A5

DHT dht(DHT22_PIN, DHT22);

int val;

void setRGB(int r, int g, int b);
void displayHeatMap(float val, float minV, float maxV);

const int heatMap[7][3] = {
  {0,   0,   0},   // 0: Black
  {0,   0,   255}, // 1: Blue
  {0,   255, 255}, // 2: Cyan
  {0,   255, 0},   // 3: Green
  {255, 255, 0},   // 4: Yellow
  {255, 0,   0},   // 5: Red
  {255, 255, 255}  // 6: White
};

void setup() {
  Serial.begin(9600);
  
  pinMode(RedPin, OUTPUT);
  pinMode(GreenPin, OUTPUT);
  pinMode(BluePin, OUTPUT);
  pinMode(MachineRedpin, OUTPUT);
  pinMode(MachineGreenpin, OUTPUT);

  pinMode(A5, INPUT);

  dht.begin();

  delay(2500);

  Serial.println("System Ready");
}

void loop() {
  float tempC = dht.readTemperature();
  int moisture = analogRead(MOISTURE_PIN);
  
  if (isnan(tempC)) {
    Serial.println("Failed to read from temperature sensor!");
    setRGB(0, 0, 25); 
  } else {
    displayHeatMap(tempC, 20.0, 35.0);
    Serial.print("Temp: "); Serial.println(tempC);
  }

  if (isnan(moisture)) {
    Serial.println("Failed to read from moisture sensor!");
  } else {
    Serial.print("Moisture: "); Serial.println(moisture);

    if (moisture < 500) {
      digitalWrite(MachineRedpin, HIGH);
      digitalWrite(MachineGreenpin, LOW);
    } else if ( moisture >= 500 && moisture < 1000) {
      digitalWrite(MachineRedpin, LOW);
      digitalWrite(MachineGreenpin, HIGH);
    } else {
      digitalWrite(MachineRedpin, LOW);
      digitalWrite(MachineGreenpin, LOW);
    }
  }

  delay(2500);
}

void displayHeatMap(float val, float minV, float maxV) {
  float percentage = (constrain(val, minV, maxV) - minV) / (maxV - minV);
  
  float abstractIdx = percentage * 6.0; 
  int index = (int)abstractIdx;
  float fraction = abstractIdx - index;

  if (index >= 6) {
    setRGB(heatMap[6][0], heatMap[6][1], heatMap[6][2]);
    return;
  }

  // Interpolate (Lerp) between the current color and the next one
  int r = heatMap[index][0] + (heatMap[index+1][0] - heatMap[index][0]) * fraction;
  int g = heatMap[index][1] + (heatMap[index+1][1] - heatMap[index][1]) * fraction;
  int b = heatMap[index][2] + (heatMap[index+1][2] - heatMap[index][2]) * fraction;

  setRGB(r, g, b);
}

void setRGB(int r, int g, int b) {
  analogWrite(RedPin, r);
  analogWrite(GreenPin, g);
  analogWrite(BluePin, b);
}