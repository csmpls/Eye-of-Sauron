
/*

//////////////////////////////////////////

          eye of sauron
          client
          (c) nick merrill 2013

//////////////////////////////////////////

*/

import java.io.*;
import processing.serial.*;
import mindset.*;
import processing.net.*;
import java.util.Iterator;
import controlP5.*;
import ddf.minim.*;


String server_ip = "10.0.1.12";

// Declare a client
Client client;
// A thread to send requests every so often
RequestThread requestThread;
// boolean to check if the server has accepted our handshake
boolean serverReceivedHandshake = false;

// String to hold the user's name
String name;
// Used to indicate a new message
float newMessageColor = 0;
// A String to hold whatever the server says
String messageFromServer = "";
String my_ip;

//Neurosky business
Neurosky neurosky = new Neurosky();
//on mac /dev/     on windows, COM#
String com_port = "/dev/tty.MindWave";
Detector detector = new Detector(); //this is our focus detector

PFont f;
ControlP5 cp5; 
Minim minim;
AudioSample enter_foc_chime, leave_foc_chime;

void setup() {
  
  //graphics
  size(400,600);
  f = createFont("Arial*",16,true);

  //initialize neurosky
  neurosky.initialize(this, com_port, false);

  //connect to the server
  client = new Client(this,server_ip, 5204);
  // start a request thread
  requestThread = new RequestThread();
  requestThread.start();

  cp5 = new ControlP5(this);

  cp5.addTextfield("username")
     .setPosition(20,100)
     .setSize(200,40)
     .setFont(f)
     .setFocus(true)
     .setColor(color(220,220,220))
     ;

  //sounds to indicate entering and leaving focus
  minim = new Minim(this);
  enter_foc_chime = minim.loadSample(dataPath("enter_foc_chime.wav"), 512);
  leave_foc_chime = minim.loadSample(dataPath("leave_foc_chime.wav"), 512);


    // detector runs in a separate thread
    // it samples the neurosky once every 250ms
    detector.start();
}


void draw() {
  background(0);

  neurosky.update();
  


  // if the user's set her name but we still aren't connected to server,
  if (!serverReceivedHandshake && name !=null) 
    text("havent met server yet",40,140);

  else if (name  != null)
    //draw list of all users
    drawClientList(messageFromServer); 

  // Fade message from server to white
  newMessageColor = constrain(newMessageColor+1,200,255); 
  
  //draw data from neurosky
  drawNeuroskyFeedback();


  
  // If there is information available to read
  // (we know there is a message from the Server when there are greater than zero bytes available.)
  if (client.available() > 0) { 
    // Read it as a String
    messageFromServer = client.readString();
    //messages will either be server handshakes 
    // (in the format [ip]:[name] )
    // or lists of user data
    // (in the format list:name,data;name,data )
    String[] message = messageFromServer.split("[:]");

    //is this the packet telling us our IP, as the server sees it?
    //if our ip is null, we assume that the new ip being announced is ours
    if (message[0].equals("new") && my_ip == null) {
      my_ip = message[1];
    }
    // is this a handshake?
    if (message[0].equals(my_ip)) {
      //if so, we're all set.
      serverReceivedHandshake = true;
    }

    //this is where we collect everyone's user data
    // we might use this to show all connected users and what they're status is
    else if (message[0].equals("list")) {

      //user data stream comes in the format:
      //list:name,data;name,data
      String[] data = message[1].split(";");

      for (int i=0; i<data.length; i++) {
        // the first string in this array is the username
        // the second string in this array is that user's data
        String[] user = data[i].split(",");
      
       }

      //this is just for testing - seeing what the raw message stream is
      messageFromServer = message[1];
    }

    // Set brightness to 0 to commemorate a received message
    newMessageColor = 0;
  }
}

void drawClientList(String msg) {
  
  
  textFont(f);
  textAlign(LEFT);

  textSize(9);
  text("CONNECTED USERS", 40, 60);

  textSize(16);

  String userlist[] = msg.split(";");
  for (int i = 0; i < userlist.length; i++) {

    try {
      String user_data[] = userlist[i].split(",");
      
      //check if user is in focus mode
      if(Integer.parseInt(user_data[1]) == 0)
        fill(255);
      else
        fill(120);

      text(user_data[0], 40, 80+(i*20));
    } catch (Exception e) {}
  }
}


void drawNeuroskyFeedback() {
 
  fill(newMessageColor);

  //attention reading
  textSize(9);
  text("ATTN READING", 300,100);
  textSize(16);
  text(neurosky.attn_pulse, 300,120);

  //focus detector reading
  textSize(9);
  text("FOCUS DETECTOR", 300,140);
  if (detector.focus_mode) {
    noStroke();
    fill(220,255,200);
  } else {
    noFill();
    stroke(255);
  }
      rect(310, 160, 40, 30);
}


public void username(String theText) {
  // automatically receives results from controller input
  name = theText;
  cp5.get(Textfield.class,"username").remove();
}


void sendUserHandshake() {
  //format for all messages to server: [ip]:[message]
  //handshake format is: [ip]:name,[name]
  String handshake = my_ip + ":name," + name;
  client.write(handshake); 
}




// --------------- !
// ----------------------- !a
// ---------------------------------!
// void sendUserData()
// --
// This is a template for function that sends
// neurosky data to the server.
// 
// We are concerned with privacy, security and lightweight client-server communication.
// Whenever possible, Neurosky data should be processed clientside.
//
// ---------------------------------!
// ----------------------- !
// --------------- !
void sendUserData() {
 
  //format for all messages to server: [ip]:[message]
  //format for user data is: [ip]:data,[name]
 
  int userData = 0;
  if (detector.focus_mode)
    userData = 1;

  String request = my_ip + ":data," + userData;
  println("sent my data over         " + request);
  client.write(request);
}






public class RequestThread extends Thread {

  private boolean running;

  void RequestThread() {
    running = false;
  }

  void start() {
    running = true;
    super.start();
  }

  void run() {

    while (running) {
      if (my_ip != null) {
        if (!serverReceivedHandshake && name!=null) {
          sendUserHandshake();
          println("attempted handshake");
        } else {
          sendUserData();
        }
      }

      //wait for interval
      try { 
        sleep((long)(1000));
      } 
      catch (Exception e) {
      }
    }
  }
}




public void stop() {
  client.stop();
}
