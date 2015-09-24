import processing.serial.*; //import serial library to communicate with the ArbotiX



  //   /$$$$$$  /$$           /$$                 /$$          
  //  /$$__  $$| $$          | $$                | $$          
  // | $$  \__/| $$  /$$$$$$ | $$$$$$$   /$$$$$$ | $$  /$$$$$$$
  // | $$ /$$$$| $$ /$$__  $$| $$__  $$ |____  $$| $$ /$$_____/
  // | $$|_  $$| $$| $$  \ $$| $$  \ $$  /$$$$$$$| $$|  $$$$$$ 
  // | $$  \ $$| $$| $$  | $$| $$  | $$ /$$__  $$| $$ \____  $$
  // |  $$$$$$/| $$|  $$$$$$/| $$$$$$$/|  $$$$$$$| $$ /$$$$$$$/
  //  \______/ |__/ \______/ |_______/  \_______/|__/|_______/ 
                                                            
                                                            
                                                            
int armPortIndex = -1; //the index of the serial port that an arm is currently connected to(relative to the list of avaialble serial ports). -1 = no serial port connected
int startupWaitTime = 10000;    //time in ms for the program to wait for a response from the ArbotiX. set to 10 seconds, though 7-8 should be enough

Serial sPort;               //serial port object, used to connect to a serial port and send data to the ArbotiX
int numSerialPorts = Serial.list().length;                 //Number of serial ports available at startup

Serial[] sPorts = new Serial[numSerialPorts];  //array of serial ports, one for each avaialable serial port.

String serialPortString;
int packetRepsonseTimeout = 5000;      //time to wait for a response from the ArbotiX Robocontroller / Arm Link Protocol

//holds the data from the last packet sent
int lastX;
int lastY;
int lastZ;
int lastWristangle;
int lastWristRotate;
int lastGripper;
int lastButton;
int lastExtended;
int lastDelta;

boolean debugConsole = true;      //change to 'false' to disable debuging messages to the console, 'true' to enable 
boolean debugGuiEvent = true;      //change to 'false' to disable debuging messages to the console, 'true' to enable 
boolean debugFile = true;      //change to 'false' to disable debuging messages to the console, 'true' to enable 
boolean debugFileCreated = true;    //change to 'false' to disable debuging messages to the console, 'true' to enable 


  
  
int currentArm = 0;          //ID of current arm. 1 = pincher, 2 = reactor, 3 = widowX, 5 = snapper
int currentMode = 0;         //Current IK mode, 1=Cartesian, 2 = cylindrical, 3= backhoe
int currentOrientation = 0;  //Current wrist oritnation 1 = straight/normal, 2=90 degrees



  //                        /$$                           /$$$ /$$$  
  //                       | $$                          /$$_/|_  $$ 
  //   /$$$$$$$  /$$$$$$  /$$$$$$   /$$   /$$  /$$$$$$  /$$/    \  $$
  //  /$$_____/ /$$__  $$|_  $$_/  | $$  | $$ /$$__  $$| $$      | $$
  // |  $$$$$$ | $$$$$$$$  | $$    | $$  | $$| $$  \ $$| $$      | $$
  //  \____  $$| $$_____/  | $$ /$$| $$  | $$| $$  | $$|  $$     /$$/
  //  /$$$$$$$/|  $$$$$$$  |  $$$$/|  $$$$$$/| $$$$$$$/ \  $$$ /$$$/ 
  // |_______/  \_______/   \___/   \______/ | $$____/   \___/|___/  
  //                                         | $$                    
  //                                         | $$                    
  //                                         |__/                    
public void setup() 
{
  size(100, 100, JAVA2D);  
  
  //print available serial ports 
  println("Available Serial Ports:");
  for(int i = 0; i< sPorts.length;i++)
  { 
    print(i);
    print(": ");
    println(Serial.list()[i]);
  }
  println("Find your serial port in the list above, and put the number in place of '-1' for the variable 'armPortIndex' ");



  armPortIndex = 3;



  //try connecting to the serial port at 38400, throw an error if there is a problem
  try
  {
    sPort =  new Serial(this, Serial.list()[armPortIndex], 38400);
  }
  catch(Exception e)
  {
    printlnDebug("Error Opening Serial Port"+ Serial.list()[armPortIndex]);
    sPort = null;
  }
    
  //connect to arm if the serial port is open    
  if (sPort != null)
  {
    //try to communicate with arm
    if (checkArmStartup() == true)
    {       
      //arm is now connected
       printlnDebug("Connected on port " + Serial.list()[armPortIndex]) ;

    }

    else  
    {

      //if arm is not found return an error
      sPort.stop();//close serial port
      sPort = null;
      printlnDebug("No Arm Found on port " + Serial.list()[armPortIndex]) ;
      printlnDebug("Try a different Port") ;

      //reprint serial ports for user
      println("Available Serial Ports:");
      for(int i = 0; i< sPorts.length;i++)
      { 
        print(i);
        print(": ");
        println(Serial.list()[i]);
      }
      println("Find your serial port in the list above, and put the number in place of '-1' for the variable 'armPortIndex' ");
    }//end checkArmStartup else
  }//end sport null if
    
  currentMode = 1;//set mode data (1 -> cartesian, 2 -> cylindrical, 3->backhoe)
  currentOrientation = 1;//set wrist orientation (1 -> Straight, 2-> 90 degrees)

  changeArmMode();//change arm mode based on mode and orientation. This will 'wake' the arm up the first time it is called
  

  getServoRegister(1, 0, 2); //get register data from servo # 1, at register 0 (model) that is 2-bytes long
  
  setServoRegister(3,25,1,1);//set register data  servo # 3 at register 25(LED) that is 1 byte long, the value 1
  
}


  //  /$$                                 /$$$ /$$$  
  // | $$                                /$$_/|_  $$ 
  // | $$  /$$$$$$   /$$$$$$   /$$$$$$  /$$/    \  $$
  // | $$ /$$__  $$ /$$__  $$ /$$__  $$| $$      | $$
  // | $$| $$  \ $$| $$  \ $$| $$  \ $$| $$      | $$
  // | $$| $$  | $$| $$  | $$| $$  | $$|  $$     /$$/
  // | $$|  $$$$$$/|  $$$$$$/| $$$$$$$/ \  $$$ /$$$/ 
  // |__/ \______/  \______/ | $$____/   \___/|___/  
  //                         | $$                    
  //                         | $$                    
  //                         |__/                    
//Main Loop
public void draw()
{
  
}





/******************************************************
 *  checkArmStartup()
 *
 *  function used to check for the presense of a 
 *  ArbotiX/Arm on a serial port. 
 
 *  This function also sets the initial Global 'currentArm'
 *
 *  Parameters:
 *    None
 *
 *  Globals used:
 *    int currentArm
 *
 *  Returns: 
 *    boolean 
 *      true = arm has been detected on current serial port
 *      false = no arm detected on current serial port
 *
 ******************************************************/ 
boolean checkArmStartup()
{
  byte[] returnPacket = new byte[5];  //byte array to hold return packet, which is 5 bytes long
  long startTime = millis();
  long currentTime = startTime;
  printlnDebug("Checking for arm on startup "); 
  while(currentTime - startTime < startupWaitTime )
  {
    delayMs(100);  //The ArbotiX has a delay of 50ms between starting the serial continuing the program, include an extra 10ms for other ArbotiX startup tasks
      
      //proceed if the serial port is not null
      if(sPort != null)
      {
        
        printlnDebug("Checking for arm on startup - index# " + armPortIndex); 
        sendCommanderPacket(0, 200, 200, 0, 512, 256, 128, 0, 112);    //send a commander style packet - the first 8 bytes are inconsequntial, only the last byte matters. '112' is the extended byte that will request an ID packet
        returnPacket = readFromArmFast(5);//read raw data from arm, complete with wait time
        
        if(verifyPacket(returnPacket) == true)
        {
          currentArm = returnPacket[1]; //set the current arm based on the return packet
          printlnDebug("Startup Arm #" +currentArm+ " Found"); 
          //setPositionParameters();      //set the GUI default/min/maxes and field lables
          
          return(true) ;                //Return a true signal to signal that an arm has been found
        }
      }
    

    currentTime = millis();
  }  
  armPortIndex = -1;
  return(false);
 

}


/******************************************************
 *  isArmConnected()
 *
 *  generic function to check for the presence of an arm
 *  during normal operation.
 *
 *  Parameters:
 *    None
 *
 *  Globals used:
 *    int currentArm
 *
 *  Returns: 
 *    boolean 
 *      true = arm has been detected on current serial port
 *      false = no arm detected on current serial port
 *
 ******************************************************/ 
boolean isArmConnected()
{  
  byte[] returnPacket = new byte[5];//return id packet is 5 bytes long
 
  printlnDebug("Checking for arm -  sending packet"); 
  sendCommanderPacket(0, 200, 200, 0, 512, 256, 128, 0, 112);    //send a commander style packet - the first 8 bytes are inconsequntial, only the last byte matters. '112' is the extended byte that will request an ID packet
  
  returnPacket = readFromArm(5);//read raw data from arm, complete with wait time

  if(verifyPacket(returnPacket) == true)
  {
    printlnDebug("Arm Found"); 
    return(true) ;
  }
  else
  {
    printlnDebug("No Arm Found"); 
    return(false); 
  }
}

/******************************************************
 *  putArmToSleep()
 *
 *  function to put the arm to sleep. This will move 
 *  the arm to a 'rest' position and then turn the 
 * torque off for the servos
 *
 *  Parameters:
 *    None
 *
 *
 *  Returns: 
 *    boolean 
 *      true = arm has been put to sleep
 *      false = no return packet was detected from the arm.
 *
 ******************************************************/ 
boolean putArmToSleep()
{
  printDebug("Attempting to put arm in sleep mode - "); 
  sendCommanderPacket(0,0,0,0,0,0,0,0,96);//only the last/extended byte matters - 96 signals the arm to go to sleep
  
  byte[] returnPacket = new byte[5];//return id packet is 5 bytes long
  returnPacket = readFromArm(5);//read raw data from arm
  if(verifyPacket(returnPacket) == true)
  {
    printlnDebug("Sleep mode success!"); 
    return(true) ;
  }
  else
  {
    printlnDebug("Sleep mode-No return packet detected"); 
   // displayError("There was a problem putting the arm in sleep mode","");
    return(false); 
  }
}


/******************************************************
 *  changeArmMode()
 *
 *  sends a packet to set the arms mode and orientation
 *  based on the global mode and orientation values
 *  This function will send a packet with the extended 
 *  byte coresponding to the correct IK mode and wrist 
 *  orientation. The arm will move from its current 
 *  position to the 'home' position for the current 
 *  mode.
 *  Backhoe mode does not have different straight/
 *  90 degree modes.
 *  
 *  Extended byte - Mode 
 *  32 - cartesian, straight mode
 *  40 - cartesian, 90 degree mode
 *  48 - cylindrical, straight mode
 *  56 - cylindrical, 90 degree mode
 *  64 - backhoe
 *  
 *  Parameters:
 *    None
 *
 *  Globals used:
 *    currentMode
 *    currentOrientation
 *
 *  Returns: 
 *    boolean 
 *      true = arm has been put in the mode correctly
 *      false = no return packet was detected from the arm.
 *
 ******************************************************/ 
boolean changeArmMode()
{
  
  byte[] returnPacket = new byte[5];//return id packet is 5 bytes long
  
 //switch based on the current mode
 switch(currentMode)
  {
    //cartesian mode case
    case 1:
      //switch based on the current orientation
      switch(currentOrientation)
      {
        case 1:
          sendCommanderPacket(0,0,0,0,0,0,0,0,32);//only the last/extended byte matters, 32 = cartesian, straight mode
          printDebug("Setting Arm to Cartesian IK mode, Gripper Angle Straight - "); 
          break;
        case 2:
          sendCommanderPacket(0,0,0,0,0,0,0,0,40);//only the last/extended byte matters, 40 = cartesian, 90 degree mode
          printDebug("Setting Arm to Cartesian IK mode, Gripper Angle 90 degree - "); 
          break;
      }//end orientation switch
      break;//end cartesian mode case
      
    //cylindrical mode case
    case 2:
      //switch based on the current orientation
      switch(currentOrientation)
      {
        case 1:
          sendCommanderPacket(0,0,0,0,0,0,0,0,48);//only the last/extended byte matters, 48 = cylindrical, straight mode
          printDebug("Setting Arm to Cylindrical IK mode, Gripper Angle Straight - "); 
          break;
        case 2:
          sendCommanderPacket(0,0,0,0,0,0,0,0,56);//only the last/extended byte matters, 56 = cylindrical, 90 degree mode
          printDebug("Setting Arm to Cylindrical IK mode, Gripper Angle 90 degree - "); 
          break;
      }//end orientation switch
      break;//end cylindrical mode case

    //backhoe mode case
    case 3:
      sendCommanderPacket(0,0,0,0,0,0,0,0,64);//only the last/extended byte matters, 64 = backhoe
          printDebug("Setting Arm to Backhoe IK mode - "); 
      break;//end backhoe mode case
  } 
  
  returnPacket = readFromArm(5);//read raw data from arm
  if(verifyPacket(returnPacket) == true)
  {
    printlnDebug("Response succesful! Arm mode changed"); 
    return(true) ;
  }
  else
  {
    printlnDebug("No Response - Failure?"); 
    
   // displayError("There was a problem setting the arm mode","");
    
    return(false); 
  }
  
}

/******************************************************
 *  delayMs(int)
 *
 *  function waits/blocks the program for 'ms' milliseconds
 *  Used for very short delays where the program only needs
 *  to wait and does not need to execute code
 *  
 *  Parameters:
 *    int ms
 *      time, in milliseconds to wait
 *  Returns: 
 *    void
 ******************************************************/ 
void delayMs(int ms)
{
  
  int time = millis();  //time that the program starts the loop
  while(millis()-time < ms)
  {
     //loop/do nothing until the different between the current time and 'time'
  }
}


/******************************************************
 *  sendCommanderPacket(int, int, int, int, int, int, int, int, int)
 *
 *  This function will send a commander style packet 
 *  the ArbotiX/Arm. This packet has 9 bytes and includes
 *  positional data, button data, and extended instructions.
 *  This function is often used with the function
 *  readFromArm()    
 *  to verify the packet was received correctly
 *   
 *  Parameters:
 *    int x
 *      offset X value (cartesian mode), or base value(Cylindrical and backhoe mode) - will be converted into 2 bytes
 *    int y
 *        Y Value (cartesian and cylindrical mode) or shoulder value(backhoe mode) - will be converted into 2 bytes
 *    int z
 *        Z Value (cartesian and cylindrical mode) or elbow value(backhoe mode) - will be converted into 2 bytes
 *    int wristAngle
 *      offset wristAngle value(cartesian and cylindrical mode) or wristAngle value (backhoe mode) - will be converted into 2 bytes
 *    int wristRotate
 *      offset wristRotate value(cartesian and cylindrical mode) or wristRotate value (backhoe mode) - will be converted into 2 bytes
 *    int gripper
 *      Gripper Value(All modes) - will be converted into 2 bytes
 *    int delta
 *      delta(speed) value (All modes) - will be converted into 1 byte
 *    int button
 *      digital button values (All modes) - will be converted into 1 byte
 *    int extended
 *       value for extended instruction / special instruction - will be converted into 1 byte
 *
 *  Global used: sPort
 *
 *  Return: 
 *    Void
 *
 ******************************************************/ 
void sendCommanderPacket(int x, int y, int z, int wristAngle, int wristRotate, int gripper, int delta, int button, int extended)
{
   sPort.clear();//clear the serial port for the next round of communications
   
  //convert each positional integer into 2 bytes using intToBytes()
  byte[] xValBytes = intToBytes(x);
  byte[] yValBytes = intToBytes(y);
  byte[] zValBytes =  intToBytes(z);
  byte[] wristRotValBytes = intToBytes(wristRotate);
  byte[] wristAngleValBytes = intToBytes(wristAngle);
  byte[] gripperValBytes = intToBytes(gripper);
  //cast int to bytes
  byte buttonByte = byte(button);
  byte extValByte = byte(extended);
  byte deltaValByte = byte(delta);
  boolean flag = true;

 
  //calculate checksum - add all values, take lower byte (%256) and invert result (~). you can also invert results by (255-sum)
  byte checksum = (byte)(~(xValBytes[1]+xValBytes[0]+yValBytes[1]+yValBytes[0]+zValBytes[1]+zValBytes[0]+wristAngleValBytes[1]+wristAngleValBytes[0]+wristRotValBytes[1]+wristRotValBytes[0]+gripperValBytes[1]+gripperValBytes[0]+deltaValByte + buttonByte+extValByte)%256);

  //send commander style packet. Following labels are for cartesian mode, see function comments for clyindrical/backhoe mode
    //try to write the first header byte
    try
    {
      sPort.write(0xff);//header        
    }
    //catch an exception in case of serial port problems
    catch(Exception e)
    {
       printlnDebug("Error: packet not sent: " + e + ": 0xFF 0x" +hex(xValBytes[1]) +" 0x" +hex(xValBytes[0]) +" 0x" +hex(yValBytes[1]) +" 0x" +hex(yValBytes[0])+" 0x" +hex(zValBytes[1])+" 0x" +hex(zValBytes[0]) +" 0x" +hex(wristAngleValBytes[1]) +" 0x" +hex(wristAngleValBytes[0]) +" 0x" + hex(wristRotValBytes[1])+" 0x" +hex(wristRotValBytes[0]) +" 0x" + hex(gripperValBytes[1])+" 0x" + hex(gripperValBytes[0])+" 0x" + hex(deltaValByte)+" 0x" +hex(buttonByte) +" 0x" +hex(extValByte) +" 0x"+hex(checksum) +"",2); 
       flag = false;
    }   
    if(flag == true)
    {
      sPort.write(xValBytes[1]); //X Coord High Byte
      sPort.write(xValBytes[0]); //X Coord Low Byte
      sPort.write(yValBytes[1]); //Y Coord High Byte
      sPort.write(yValBytes[0]); //Y Coord Low Byte
      sPort.write(zValBytes[1]); //Z Coord High Byte
      sPort.write(zValBytes[0]); //Z Coord Low Byte
      sPort.write(wristAngleValBytes[1]); //Wrist Angle High Byte
      sPort.write(wristAngleValBytes[0]); //Wrist Angle Low Byte
      sPort.write(wristRotValBytes[1]); //Wrist Rotate High Byte
      sPort.write(wristRotValBytes[0]); //Wrist Rotate Low Byte
      sPort.write(gripperValBytes[1]); //Gripper High Byte
      sPort.write(gripperValBytes[0]); //Gripper Low Byte
      sPort.write(deltaValByte); //Delta Low Byte  
      sPort.write(buttonByte); //Button byte  
      sPort.write(extValByte); //Extended instruction  
      sPort.write(checksum);  //checksum
      printlnDebug("Packet Sent: 0xFF 0x" +hex(xValBytes[1]) +" 0x" +hex(xValBytes[0]) +" 0x" +hex(yValBytes[1]) +" 0x" +hex(yValBytes[0])+" 0x" +hex(zValBytes[1])+" 0x" +hex(zValBytes[0]) +" 0x" +hex(wristAngleValBytes[1]) +" 0x" +hex(wristAngleValBytes[0]) +" 0x" + hex(wristRotValBytes[1])+" 0x" +hex(wristRotValBytes[0]) +" 0x" + hex(gripperValBytes[1])+" 0x" + hex(gripperValBytes[0])+" 0x" + hex(deltaValByte)+" 0x" +hex(buttonByte) +" 0x" +hex(extValByte) +" 0x"+hex(checksum) +"",2); 
    }
  
    
  
  
  
  
         
}


//sends the commander packet if an only if the packet is different from the last one sent with this function. This stops duplicate packets from being sent multile times in a row
void sendCommanderPacketWithCheck(int x, int y, int z, int wristAngle, int wristRotate, int gripper, int delta, int button, int extended)
{



   
   
    //check for changes - if there are no changes then don't send the packet to avoid sending multiple identical packets unnesscarsily

  if(  lastX != x || lastY != y || lastZ != z || lastWristangle != wristAngle || lastWristRotate != wristRotate || lastGripper != gripper || lastButton != button || lastExtended != extended || lastDelta != delta)
  {
    sendCommanderPacket(x,y, z, wristAngle,  wristRotate,  gripper,  delta,  button,  extended);
  }
    
    
 
     //holds the data from the last packet sent
  lastX = x;
  lastY = y;
  lastZ = z;
  lastWristangle = wristAngle;
  lastWristRotate = wristRotate;
  lastGripper = gripper;
  lastButton = button;
  lastExtended = extended;
  lastDelta = delta;
   
  

}

/******************************************************
 *  intToBytes(int)
 *
 *  This function will take an interger and convert it
 *  into two bytes. These bytes can then be easily 
 *  transmitted to the ArbotiX/Arm. Byte[0] is the low byte
 *  and Byte[1] is the high byte
 *   
 *  Parameters:
 *    int convertInt
 *      integer to be converted to bytes
 *  Return: 
 *    byte[]
 *      byte array with two bytes Byte[0] is the low byte and Byte[1] 
 *      is the high byte
 ******************************************************/ 
byte[] intToBytes(int convertInt)
{
  byte[] returnBytes = new byte[2]; // array that holds the two bytes to return
  byte mask = byte(255);          //mask for the low byte (255/0xff)
  returnBytes[0] =byte(convertInt & mask);//low byte - perform an '&' operation with the byte mask to remove the high byte
  returnBytes[1] =byte((convertInt>>8) & mask);//high byte - shift the byte to the right 8 bits. perform an '&' operation with the byte mask to remove any additional data
  return(returnBytes);  //return byte array
  
}

/******************************************************
 *  bytesToInt(byte[])
 *
 *  Take two bytes and convert them into an integer
 *   
 *  Parameters:
 *    byte[] convertBytes
 *      bytes to be converted to integer
 *  Return: 
 *    int
 *      integer value from 2 butes
 ******************************************************/ 
int bytesToInt(byte[] convertBytes)
{
  return((int(convertBytes[1]<<8))+int(convertBytes[0]));//shift high byte up 8 bytes, and add it to the low byte. cast to int to ensure proper signed/unsigned behavior
}





int analogRead(int analogPort)
{
  byte[] returnPacket = new byte[5];  //byte array to hold return packet, which is 5 bytes long
  int analog = 0;
  printlnDebug("sending request for anlaog 1"); 
  int analogExtentded = 200 + analogPort;
  sendCommanderPacket(0, 0, 0, 0, 0, 0, 0, 0, analogExtentded);    //send a commander style packet - the first 8 bytes are inconsequntial, only the last byte matters. '112' is the extended byte that will request an ID packet
  returnPacket = readFromArmFast(5);//read raw data from arm, complete with wait time
  byte[] analogBytes = {returnPacket[3],returnPacket[2]};
  analog = bytesToInt(analogBytes);
  
  printlnDebug("Return Packet" + int(returnPacket[0]) + "-" +  int(returnPacket[1]) + "-"  + int(returnPacket[2]) + "-"  + int(returnPacket[3]) + "-"  + int(returnPacket[4]));
  printlnDebug("analog value: " + analog);
  
  return(analog);
        
}

int getServoRegister(int servoId, int registerNumber, int length)
{
  byte[] returnPacket = new byte[5];  //byte array to hold return packet, which is 5 bytes long
  int registerValue;
  printlnDebug("sending request for Servo Register Data"); 
  int getServoDataExtInst = 0x81;
  sendCommanderPacket(servoId, registerNumber, length, 0, 0, 0, 0, 0, getServoDataExtInst);    //send a commander style packet - the first 8 bytes are inconsequntial, only the last byte matters. '112' is the extended byte that will request an ID packet
  returnPacket = readFromArmFast(5);//read raw data from arm, complete with wait time
  byte[] analogBytes = {returnPacket[3],returnPacket[2]};
  registerValue = bytesToInt(analogBytes);
  
  printlnDebug("Return Packet" + int(returnPacket[0]) + "-" +  int(returnPacket[1]) + "-"  + int(returnPacket[2]) + "-"  + int(returnPacket[3]) + "-"  + int(returnPacket[4]));
  printlnDebug("registerValue value: " + registerValue);
  
  return(registerValue);
        
}



int setServoRegister(int servoId, int registerNumber, int length, int registerValue)
{
  byte[] returnPacket = new byte[5];  //byte array to hold return packet, which is 5 bytes long

  printlnDebug("sending write for Servo Register Data"); 
  int setServoDataExtInst = 0x82;
  sendCommanderPacket(servoId, registerNumber, length, registerValue, 0, 0, 0, 0, setServoDataExtInst);    //send a commander style packet - the first 8 bytes are inconsequntial, only the last byte matters. '112' is the extended byte that will request an ID packet
  returnPacket = readFromArmFast(5);//read raw data from arm, complete with wait time
  byte[] analogBytes = {returnPacket[3],returnPacket[2]};
  registerValue = bytesToInt(analogBytes);
  
  printlnDebug("Return Packet" + int(returnPacket[0]) + "-" +  int(returnPacket[1]) + "-"  + int(returnPacket[2]) + "-"  + int(returnPacket[3]) + "-"  + int(returnPacket[4]));
  printlnDebug("registerValue value: " + registerValue);
  
  return(registerValue);
        
}




/******************************************************
 *  printlnDebug()
 *
 *  function used to easily enable/disable degbugging
 *  enables/disables debugging to the console
 *  prints a line to the output
 *
 *  Parameters:
 *    String message
 *      string to be sent to the debugging method
 *    int type
 *        Type of event
 *         type 0 = normal program message
 *         type 1 = GUI event
 *         type 2 = serial packet 
 *  Globals Used:
 *      boolean debugGuiEvent
 *      boolean debugConsole
 *      boolean debugFile
 *      PrintWriter debugOutput
 *      boolean debugFileCreated
 *  Returns: 
 *    void
 ******************************************************/
void printlnDebug(String message, int type)
{
  if (debugConsole == true)
  {
    if ((type == 1) || type == 0 || type == 2)
    {
      println(message);
    }
  }

  if (debugFile == true)
  {

    if ((type == 1) || type == 0 || type == 2)
    {

      if (debugFileCreated == false)
      {
//        debugOutput = createWriter("debugArmLink.txt");
//        debugOutput.println("Started at "+ day() +"-"+ month() +"-"+ year() +" "+ hour() +":"+ minute() +"-"+ second() +"-"); 
//        debugFileCreated = true;
      }


     // debugOutput.println(message);
    }
  }
}

//wrapper for printlnDebug(String, int)
//assume normal behavior, message type = 0
void printlnDebug(String message)
{
  printlnDebug(message, 0);
}

/******************************************************
 *  printlnDebug()
 *
 *  function used to easily enable/disable degbugging
 *  enables/disables debugging to the console
 *  prints normally to the output
 *
 *  Parameters:
 *    String message
 *      string to be sent to the debugging method
 *    int type
 *        Type of event
 *         type 0 = normal program message
 *         type 1 = GUI event
 *         type 2 = serial packet 
 *  Globals Used:
 *      boolean debugGuiEvent
 *      boolean debugConsole
 *      boolean debugFile
 *      PrintWriter debugOutput
 *      boolean debugFileCreated
 *  Returns: 
 *    void
 ******************************************************/
void printDebug(String message, int type)
{
  if (debugConsole == true)
  {
    if ((type == 1 & debugGuiEvent == true)  || type == 2)
    {
      print(message);
    }
  }

  if (debugFile == true)
  {

    if ((type == 1 & debugGuiEvent == true) || type == 0 || type == 2)
    {

      if (debugFileCreated == false)
      {
        //debugOutput = createWriter("debugArmLink.txt");

        //debugOutput.println("Started at "+ day() +"-"+ month() +"-"+ year() +" "+ hour() +":"+ minute() +"-"+ second() ); 

        debugFileCreated = true;
      }


      //debugOutput.print(message);
    }
  }
}

//wrapper for printlnDebug(String, int)
//assume normal behavior, message type = 0
void printDebug(String message)
{
  printDebug(message, 0);
}


/******************************************************
 *  readFromArm(int, boolean)
 *
 *  reads data back from the ArbotiX/Arm
 *
 *  Normally this is called from readFromArm(int) - 
 *  this will block the program and make it wait 
 * 'packetRepsonseTimeout' ms. Most of the time the program
 *  will need to wait, as the arm is moving to a position
 *  and will not send a response packet until it has 
 *  finished moving to that position.
 *  
 *  However this will add a lot of time to the 'autoSearch' 
 *  functionality. When the arm starts up it will immediatley send a
 *  ID packet to identify itself so a non-waiting version is   
 *  avaialble -  readFromArmFast(int) which is equivalent to
 *  readFromArm(int, false)
 *
 *  Parameters:
 *    int bytesExpected
 *      # of bytes expected in the response packet
 *    boolean wait
 *        Whether or not to wait 'packetRepsonseTimeout' ms for a response
 *         true = wait
 *         false = do not wait
 *  Globals Used:
 *      Serial sPort
 *      long packetRepsonseTimeout
 *
 *  Returns: 
 *    byte[]  responseBytes
 *      byte array with response data from ArbotiX/Arm
 ******************************************************/ 
byte[] readFromArm(int bytesExpected, boolean wait)
{
  byte[] responseBytes = new byte[bytesExpected];    //byte array to hold response data
  delayMs(100);//wait a minimum 100ms to ensure that the controller has responded - this applies to both wait==true and wait==false conditions
  
  byte bufferByte = 0;  //current byte that is being read
  long startReadingTime = millis();//time that the program started looking for data
  
  printDebug("Incoming Raw Packet from readFromArm():",2); //debug
  
  //if the 'wait' flag is TRUE this loop will wait until the serial port has data OR it has waited more than packetRepsonseTimeout milliseconds.
  //packetRepsonseTimeout is a global variable
  
  while(wait == true & sPort.available() < bytesExpected  & millis()-startReadingTime < packetRepsonseTimeout)
  {
     //do nothing, just waiting for a response or timeout
  }
  
  for(int i =0; i < bytesExpected;i++)    
  {
    // If data is available in the serial port, continute
    if(sPort.available() > 0)
    {
      bufferByte = byte(sPort.readChar());
      responseBytes[i] = bufferByte;
      printDebug(hex(bufferByte) + "-",2); //debug 
    }
    else
    {
      printDebug("NO BYTE-");//debug
    }
  }//end looking for bytes from packet
  printlnDebug(" ",2); //debug  finish line
  
  sPort.clear();  //clear serial port for the next read
  
  return(responseBytes);  //return serial data
}


//wrapper for readFromArm(int, boolean)
//assume normal behavior, wait = true
byte[] readFromArm(int bytesExpected)
{
  return(readFromArm(bytesExpected,true));
}


//wrapper for readFromArm(int, boolean)
//wait = false. Used for autosearch/startup
byte[] readFromArmFast(int bytesExpected)
{
  return(readFromArm(bytesExpected,false));
}




/******************************************************
 *  verifyPacket(int, boolean)
 *
 *  verifies a packet received from the ArbotiX/Arm
 *
 *  This function will do the following to verify a packet
 *  -calculate a local checksum and compare it to the
 *    transmitted checksum 
 *  -check the error byte for any data 
 *  -check that the armID is supported by this program
 *
 *  Parameters:
 *    byte[]  returnPacket
 *      byte array with response data from ArbotiX/Arm
 *
 *
 *  Returns: 
 *    boolean verifyPacket
 *      true = packet is OK
 *      false = problem with the packet
 *
 *  TODO: -Modify to return specific error messages
 *        -Make the arm ID check modular to facilitate 
 *         adding new arms.
 ******************************************************/ 
boolean verifyPacket(byte[] returnPacket)
{
  int packetLength = returnPacket.length;  //length of the packet
  int tempChecksum = 0; //int for temporary checksum calculation
  byte localChecksum; //local checksum calculated by processing
  
  printDebug("Begin Packet Verification of :");
  for(int i = 0; i < packetLength;i++)
  {
    printDebug(returnPacket[i]+":");
  }
  //check header, which should always be 255/0xff
  if(returnPacket[0] == byte(255))
  {  
      //iterate through bytes # 1 through packetLength-1 (do not include header(0) or checksum(packetLength)
      for(int i = 1; i<packetLength-1;i++)
      {
        tempChecksum = int(returnPacket[i]) + tempChecksum;//add byte value to checksum
      }
  
      localChecksum = byte(~(tempChecksum % 256)); //calculate checksum locally - modulus 256 to islotate bottom byte, then invert(~)
      
      //check if calculated checksum matches the one in the packet
      if(localChecksum == returnPacket[packetLength-1])
      {
        //check is the error packet is 0, which indicates no error
        if(returnPacket[3] == 0)
        {
          //check that the arm id packet is a valid arm
          if(returnPacket[1] == 1 || returnPacket[1] == 2 || returnPacket[1] == 3 || returnPacket[1] == 5)
          {
            printlnDebug("verifyPacket Success!");
            return(true);
          }
          else {printlnDebug("verifyPacket Error: Invalid Arm Detected! Arm ID:"+returnPacket[1]);}
        }
        else {printlnDebug("verifyPacket Error: Error Packet Reports:"+returnPacket[3]);}
      }
      else {printlnDebug("verifyPacket Error: Checksum does not match: Returned:"+ returnPacket[packetLength-1] +" Calculated:"+localChecksum );}
  }
  else {printlnDebug("verifyPacket Error: No Header!");}

  return(false);

}


