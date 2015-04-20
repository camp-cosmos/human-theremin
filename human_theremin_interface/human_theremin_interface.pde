/*
  human_theremin_interface.pde
  Mark Abrams, 05/16/2011
  
  Firmware for an Arduino-based human theremin interface.  PWM-outs from some set number of
  ultrasonic rangefinders are connected to the digital ins of an Arduino.  pulseIn is used to 
  measure the time of the HIGH phase of the pulse train, and that time is scaled to centimeters
  according to the information provided in the data sheet.  Maxbotix LV-MaxSonar-EZ1 is the
  rangefinder used here.  The values are transmitted to a host computer via the serial port.
  The transmissions are sent in the following format:
  
  Byte 0:  Number of additional bytes in this transmission
  Byte 1...:  Value of this rangefinder (uint8).
*/

// NUM_SENSORS should be set to the number of sensors being used, and the sensorPins array should be
//  initialized such that sensorPins[i] is the input pin for sensor number i.
const int NUM_SENSORS = 5;
int sensorPins[] = {2, 5, 8, 11, 13};

// Baud rate for the serial port
const int BAUD_RATE = 9600;

// Time between iterations of the sensor-checking loop, in milliseconds
const int DELAY_TIME_MILLIS = 50;

// Scale factor from microseconds to centimeters.  This information comes from the sensor datasheet.
const double US_TO_CM_SCALE_FACTOR = (1.0 / 147.0) * 2.54;  // 147 us/in (from Maxbotix datasheet) and 2.54 cm/in

// Sometimes some weird values come out of these sensors, or the microcontroller miscalculates pulse time
//  and comes up with something totally crazy.  Set some high and low limits to make sure our values stay
//  within range
const int MIN_DISTANCE = 0;
const int MAX_DISTANCE = 255;

void setup() {
  for (int i = 0; i < NUM_SENSORS; i++)
    pinMode(sensorPins[i], INPUT);
    
  Serial.begin(9600);
}

void loop() {
  uint8_t sensorVals[NUM_SENSORS];
  
  for (int i = 0; i < NUM_SENSORS; i++) {
    int pin = sensorPins[i];
    int pulseLength = pulseIn(pin, HIGH);
    int distance = usToCm(pulseLength);
    
    if (distance > MAX_DISTANCE)
      distance = MAX_DISTANCE;
    else if (distance < MIN_DISTANCE)
      distance = MIN_DISTANCE;
      
    sensorVals[i] = (uint8_t) distance;
  }
  
  transmitSensorVals(NUM_SENSORS, sensorVals);
  
  delay(DELAY_TIME_MILLIS);
}

int usToCm(int us) {
  return (int) ((double) us) * US_TO_CM_SCALE_FACTOR;
}

void transmitSensorVals(int arraySize, uint8_t values[]) {
  Serial.write(arraySize);
  Serial.write(values, arraySize);
}
