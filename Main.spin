{{
───────────────────────────────────────────────── 
based on code by Jon McPhalen, and Mike Gebhard
───────────────────────────────────────────────── 
}}

{
About:
Ed's pool server/controller
}


CON
  _clkmode = xtal1 + pll16x     
  _xinfreq = 5_000_000

  MAX_PACKET_SIZE = $800 '1472   '$800 = 2048
  RxTx_BUFFER     = $600         '$600 = 1536
  TEMP_BUFFER     = $300         '$5B4 = 1460 
  TCP_PROTOCOL    = %0001        '$300 = 768 
  UDP_PROTOCOL    = %0010        '$200 = 512 
  TCP_CONNECT     = $04          '$100 = 256                 
  DELAY           = $05
  MAX_TRIES       = $15                  

                                

  RD_ROM     = $33                                              ' 1W ROM commands
  MATCH_ROM  = $55
  SKIP_ROM   = $CC
  SRCH_ROM   = $F0
  ALARM_SRCH = $EC
  
  CVRT_TEMP  = $44                                              ' DS1822 commands
  WR_SPAD    = $4E
  RD_SPAD    = $BE
  COPY_SPAD  = $48 
  RD_EE      = $B8
  RD_POWER   = $B4

    #1, HOME, #8, BKSP, TAB, LF, CLREOL, CLRDN, CR, #16, CLS      ' PST formmatting control    
 
  'I2C Buss Addresses
  SoA_add = 32                 '0,0,0
  SoB_add = 33                 '0,0,1
  SoC_add = 34                 '0,1,0

  SiA_add = 37                 '1,0,1
  SiB_add = 36                 '1,0,0
  
    'W5100 Interface
   #0, W5100_DATA0, W5100_DATA1, W5100_DATA2, W5100_DATA3, W5100_DATA4
   #5, W5100_DATA5, W5100_DATA6, W5100_DATA7, W5100_ADDR0, W5100_ADDR1
  #10, W5100_WR, W5100_RD, W5100_CS, W5100_INT, W5100_RST, W5100_SEN

   BUFFER_SIZE       = 2048
  
  socketf            = 0
                                                     
  TIME_PORT         = 123
  TIMEOUT_SECS      = 10

    'USA Standard Time Zone Abbreviations
 #-10, HST,AtST,PST,MST,CST,EST,AlST
              
    'USA Daylight Time Zone Abbreviations
  #-9, HDT,AtDT,PDT,MDT,CDT,EDT,AlDT

  Zone = PDT  'GMT-8
      
VAR
  long  longHIGH,longLOW,MM_DD_YYYY,DW_HH_MM_SS 'Expected 4-contigous variables
  byte  Buffer[BUFFER_SIZE]  
  long  Today
  long  currentTime 
  long  ModeTime
  long  ontime 
  long  offtime
  byte  Mode, SMode
  long  StackSpace[20]
  long  StackSpace2[50]    
  long  StackSpace3[30]
  long  strpointer,ButtonSelection                            
  byte  snum[8]  
  long  SysTemp
  byte  eStop, PnlOpn, AB[5], ABo[5], CP[5], CPo[5], Sin2[8], RLY[5], FlowSw, SolarEnable
  
DAT
  mac                   byte    $00, $08, $DC, $16, $F1, $32
  subnet                byte    255, 255 ,255, 0
  gateway               byte    192, 168, 1, 1 
  ip                    byte    192, 168, 1, 45
  port                  word    5555
  port2                 word    5010 
  remoteIp              byte    69, 25, 96, 13
  remotePort            word    80
  uport                 word    5050 
  emailIp               byte    0, 0, 0, 0
  emailPort             word    25
  status                byte    $00, $00, $00, $00   
  rxdata                byte    $0[RxTx_BUFFER]
  txdata                byte    $0[RxTx_BUFFER]
  debug                 byte    $0
  closedState           byte    %0000
  openState             byte    %0000
  listenState           byte    %0000
  establishedState      byte    %0000
  closingState          byte    %0000
  closeWaitState        byte    %0000 
  lastEstblState        byte    %0000
  lastEstblStateDebug   byte    %0000
  udpListen             byte    %0000
  tcpMask               byte    %1111
  udpMask               byte    %0000   
  fifoSocketDepth       byte    $0
  fifoSocket            long    $00_00_00_00
  debugSemId            byte    $00
  debugCounter          long    $00
  closingTimeout        long    $00, $00, $00, $00
  dynamicContentPtr     long    @txdata
  timeIPaddr            byte    216,239,35,0
    
'-----------------------------------------------
{Create variables to hold the DS18B20 serial numbers and fill each with the respective ROM codes...}
DS1820SNBlack           BYTE    $10, $A0, $71, $7C, $02, $08, $00, $84 'Solar Return
'DS1820SNPanel           BYTE    $10, $37, $B3, $7C, $02, $08, $00, $11 'Control pannel
'DS1820SNBlue            BYTE    $10, $93, $BD, $7C, $02, $08, $00, $33 'Main System
'DS1820SNRed             BYTE    $10, $01, $C0, $7C, $02, $08, $00, $6D 'Out Side Air




Shift01 byte %00000000
Shift02 byte %00000000
Shift03 byte %00000000

P41     byte  0
P42     byte  0

P31     byte  0
P32     byte  0

P30     byte  0


Blower  Byte  0

HtrOn   Byte  0
HtrEn   Byte  0

SMon    byte  "On    ",0 
SMoff   byte  "Off   ",0
SMIdle  byte  "Idle  ",0   
SMman   byte  "ManOff",0 
SMauto  byte  "Auto  ",0
SMstop  Byte  "E-Stop",0

SMpool  byte  "Pool     ",0
SMLspa  byte  "Spa      ",0 
SMSspa  byte  "Spa      ",0
SMSolar byte  "Solar    ",0 

d1      byte  "  ",0
DspWait Long 0

  PoolWSOnTime           long     800, 800, 800, 800, 800, 800, 800                'Mon,Tues,Wed,Thur,Fri,Sat,Sun
  PoolWSOffTime          long    1050,1050,1050,1050,1050,1000,1000
  SolarOnTime            long    1400,1400,1400,1400,1400,1400,1200
  SolarOffTime           long    1420,1420,1420,1420,1420,1420,1720
  Solar2OnTime           long    1801,1801,1801,1801,1801,1800,1800
  Solar2OffTime          long    1830,1830,1830,1830,1830,1830,1830  
  SpaOnTime            long    1110,1110,1110,1110,1110, 1010, 1010
  SpaOffTime           long    1150,1150,1150,1150,1150, 1050, 1050
'-----------------------------------------------
'Pool Set Points

  
  SpHl                   byte     105 
  SpLl                   byte      96
  SpaSP                  byte     103
  SolarSP                byte      85
  PoolSP                 byte      85
  
'Web Page


  htmlstart
        byte  "HTTP/1.1 200 OK", CR, LF,0
'--------------------------------------------------------------------------------------        
htmlopt byte  "You have connected to PARELECTS Spinneret Web Server ... "
        byte  "Next meeting is January 4th, 2011",CR
        byte  "Connection: close",CR
        byte  "Content-Type: text/html", CR, LF,CR,LF,0
'--------------------------------------------------------------------------------------
html0
        byte    "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Transitional//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'>"
        byte    "<html xmlns='http://www.w3.org/1999/xhtml'>"
        byte    "<head>"
        byte    "<meta http-equiv='Content-Type' content='text/html; charset=utf-8' />"
        byte    "<title>Ed's Pool</title>"
        byte    "<style type='text/css'>"
        byte    0
        
html1
        byte    "<!--"
        byte    "body {"
        byte    "font: 100% Verdana, Arial, Helvetica, sans-serif;"
        byte    "background: #666666;"
        byte    "margin: 0;"
        byte    "padding: 0;"
        byte    "text-align: center; "
        byte    "color: #000000;}"
        byte    ".oneColElsCtr #container {"
        byte    "width: 46em;"
        byte    "background: #FFFFFF;"
        byte    "margin: 0 auto;"
        byte    "border: 1px solid #000000;"
        byte    "text-align: left; }"
        byte    ".oneColElsCtr #mainContent {"
        byte    "padding: 0 20px;}"
        byte    "-->"
        byte    "</style></head>"
        byte    0
        
html2
        byte    "<body class='oneColElsCtr'>"
        byte    "<div id='container'>"
        byte    "<div id='mainContent'>"
        byte    "<h1>Ed's Pool</h1>"
        byte    "<table align='center' border='0'>"
        byte    "<tr><td width='250'>&nbsp;</td><td width='250'>&nbsp;</td></tr>"
sysm    byte    "       <tr><td>System: Idle   </td><td>&nbsp;</td></tr>"
mpmp    byte    "    <tr><td>Main Pump: Off   </td>"
pllt    byte    "       <td>Pool Light: Off   </td></tr>"
bpmp    byte    "   <tr><td>Sweep Pump: Off   </td>"
splt    byte    "        <td>Spa Light: Off   </td></tr>"  
rtva    byte    " <tr><td>Return Valve: Pool          </td>"
blow    byte    "           <td>Blower: Off   </td></tr>" 
spva    byte    " <tr><td>Supply Valve: Pool          </td>"  
flsw    byte    "             <td>Flow: Off   </td></tr>"    
hter    byte    "       <tr><td>Heater: Off   </td>"  
aux1    byte    "            <td>Aux 1: Off   </td></tr>" 
tmpt    byte    "         <tr><td>Temp: 082    </td>"
aux2    byte    "            <td>Aux 2: Off   </td></tr>" 
tmsp    byte    "    <tr><td>Heater SP: 102   </td><td>&nbsp;</td></tr>"          
        byte    "            <tr><td>&nbsp;</td><td>&nbsp;</td></tr>"     
        byte    0
        
html3
        byte    "    <FORM ACTION='button_action'method='get' target='_parent'>"     
        byte    "    <tr><td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P51'>Pool</button></td>"
        byte    "        <td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P41'>Pool Light</button></td></tr>"
        byte    "    <tr><td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P52'>Pool w/ Sweep</button></td>"
        byte    "        <td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P42'>Spa Light</button></td></tr>"
        byte    "    <tr><td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P53'>Pool w/ Heat</button></td>"
        byte    "        <td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P30'>Blower</button></td></tr>"
        byte    "    <tr><td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P54'>Spa w/ Heat</button></td>"
        byte    "        <td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P31'>Aux 1</button></td></tr>"
        byte    "    <tr><td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P50'>System Off (Auto)</button></td>"
        byte    "        <td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P32'>Aux 2</button></td></tr>"
        byte    "    <tr><td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P20'>Heat Temp Up</button></td>"
        byte    "        <td><Button type='submit'  style='width:250px; height:50px; font-size:18px' name='P21'>Heat Temp Down</button></td></tr>"
        byte    "    <tr><td>&nbsp;</td><td>&nbsp;</td></tr></form></table>"   
        byte    0

htmlfin       

Time1   byte    "                                                                                              "
        byte    "</div></div></body></html>"     
        byte    0
               

        
OBJ
  PlxST         : "Parallax Serial Terminal"
  Socket        : "W5100_Indirect_Driver"
  STR           : "STREngine"
  expand1       : "PCF8574_i2cDriver"
  SNTP          : "SNTP Simple Network Time Protocol v2.01.spin"
  RTC           : "s-35390A_GBSbuild_02_09_2011"
  ow            : "jm_1-wire"
    
PUB Initialize | id, size, st

    RTC.start                     'Initialize On board Real Time Clock
    RTC.Set24HourMode(1)
  debug := 1

  PlxST.Start(115_200)
  pause(500)
  PlxST.str(string("5 sec wait", 13)) 
  pause(5000)
  SolarEnable  := 0
    
  'Start the W5100 driver
  if(Socket.Start)
    PlxST.str(string("W5100 Driver Started", 13))
    PlxST.str(string(13, "Status Memory Lock ID    : "))
    PlxST.dec(Socket.GetLockId)
    PlxST.char(13) 


  if(debugSemId := locknew) == -1
    PlxST.str(string("Error, no HTTP server locks available", 13))
  else
    PlxST.str(string("HTTP Server Lock ID      : "))
    PlxST.dec(debugSemId)
    PlxST.char(13)
    

  'Set the Socket addresses  
  SetMac(@mac)
  SetGateway(@gateway)
  SetSubnet(@subnet)
  SetIP(@ip)
  Pause(500)
  
  SetRTC        ' Update RTC
  Pause(1000)
   
  ' Initailize TCP sockets (defalut setting; TCP, Port, remote ip and remote port)
  repeat id from 0 to 3
    InitializeSocket(id)
    pause(50)

  ' Set all TCP sockets to listen
  PlxST.char(13) 
  repeat id from 0 to 3 
    Socket.Listen(id)
    PlxST.str(string("TCP Socket Listener ID   : "))
    PlxST.dec(id)
    PlxST.char(13)
    pause(50)

  PlxST.Str(string(13,"Started Socket Monitoring Service", 13))
 
  cognew(StatusMonitor, @StackSpace)
  pause(250)


  PlxST.Str(string(13, "Initial Socket States",13))
  StackDump

  PlxST.Str(string(13, "Initial Socket Queue",13))
  QueueDump

  PlxST.str(string(13,"//////////////////////////////////////////////////////////////",13))

  debugCounter := 0

  expand1.out(SoA_add, 255) ' Initialize i/o expanders
  expand1.out(SoB_add, 255)
  expand1.out(SoC_add, 255)
  expand1.out(SiA_add, 255)
  expand1.out(SiB_add, 255)
  IntInputs 
  pause(1000)                                  
  Mode  := 50
  SMode := 1
  SolarEnable  := 0

  TmpStart

  cognew(timer, @StackSpace2)          'Start timers and Read Local I/O
  pause(250)

   cognew(tempchecker, @StackSpace3)
  ' pause(250)
  Main                                 'Start Web server

   
PUB Main | packetSize, id, i, reset, j, temp
  '' HTTP Service
  repeat
    repeat until fifoSocket == 0
      bytefill(@rxdata, 0, RxTx_BUFFER)

      if(debug)
        PlxST.str(string(13, "----- Start of Request----------------------------",13))
        pause(DELAY)
      else
        pause(DELAY)
        
      ' Pop the next socket handle 
      id := DequeueSocket
      if(id < 0)
        next
      
      if(debug)
        PlxST.str(string(13,"ID: "))
        PlxST.dec(id)
        PlxST.str(string(13, "Request Count     : "))
        PlxST.dec(debugCounter)
        PlxST.char(13)

      packetSize := Socket.rxTCP(id, @rxdata)

      reset := false
      if ((packetSize < 12) AND (strsize(@rxdata) < 12))
        repeat i from 0 to MAX_TRIES
          'Wait for a few moments and try again
          waitcnt((clkfreq/300) + cnt)
          packetSize := Socket.rxTCP(id, @rxdata)
          PlxST.dec(packetSize)
          if(packetSize > 12)            
              PlxST.str(string(13,"* packet too big *",13))
            quit
          if(i == MAX_TRIES)
            'Clean up resource request
            Socket.Close(id)
            reset := true
            if(debug)
              PlxST.str(string(13,"* Read Failure *",13))

      '--------Parse Data Packet for Button Press-------
      strpointer := STR.findCharacters(@rxdata[0], string("GET /button_action"))
      if strpointer<>0
       bytemove(@d1,@rxdata[20],2)
       ButtonSelection := STR.decimalToNumber(@d1)

       PlxST.char(13)
       PlxST.dec(ButtonSelection)
       PlxST.char(13)
       PlxST.char(13)
       SetButtons
               
      if(reset)  
        next

      PlxST.str(@rxdata)
      PlxST.char(13)
      
      'Default page
      Index(id)
      
      'if(debug)
        'StackDump

      Socket.Disconnect(id)

      bytefill(@txdata, 0, RxTx_BUFFER)

      debugCounter++
      

  GotoMain

PRI GotoMain
  Main
  
PRI GotoTimer
  Timer

PRI Index(id) | headerLen
 { dynamicContentPtr := @txdata
  PushDynamicContent(string("HTTP/1.1 200 OK",13,10))
  PushDynamicContent(string("Content-Type: text/html",13,10))
  PushDynamicContent(string("Server: Spinneret/2.1",13,10,13,10))
  PushDynamicContent(string("<html><head><title>index</title></head><body>index</body></html>"))
  StringSend(id, @txdata)   }
  
  '--------Generate HTML data to send-------
 
    StringSend(0, @htmlstart)
      'optional HTML header
   StringSend(0, @htmlopt)
      'HTML Header
    StringSend(0, @html0)
    StringSend(0, @html1)        
    StringSend(0, @html2)       
    StringSend(0, @html3)
    StringSend(0, @htmlfin)

  bytefill(@txdata, 0, RxTx_BUFFER)
  
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Write data to a buffer
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI PushDynamicContent(content)
  ' Write the content to memory
  ' and update the pointer
  bytemove(dynamicContentPtr, content, strsize(content))
  dynamicContentPtr := dynamicContentPtr + strsize(content)
  return

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Memory Management
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI Set(DestAddress, SrcAddress, Count)
  bytemove(DestAddress, SrcAddress, Count)
  bytefill(DestAddress+Count, $0, 1)
  

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Socket helpers
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI GetTcpSocketMask(id)
  return id & tcpMask

  
PRI DecodeId(value) | tmp
    if(%0001 & value)
      return 0
    if(%0010 & value)
      return 1
    if(%0100 & value)
      return 2 
    if(%1000 & value)
      return 3
  return -1


PRI QueueSocket(id) | tmp
'' Place a socket ID in the Queue
'' to be processed

  if(fifoSocketDepth > 4)
    return false

  tmp := |< id
  
  'Unique check
  ifnot(IsUnique(tmp))
    return false
    
  tmp <<= (fifoSocketDepth++) * 8
  
  fifoSocket |= tmp

  return true


PRI IsUnique(encodedId) | tmp
  tmp := encodedId & $0F
  repeat 4
    if(encodedId & fifoSocket)
      return false
    encodedId <<= 8
  return true 
    

PRI DequeueSocket | tmp
  if(fifoSocketDepth == 0)
    return -2
  repeat until not lockset(debugSemId) 
  tmp := fifoSocket & $0F
  fifoSocket >>= 8  
  fifoSocketDepth--
  lockclr(debugSemId)
  return DecodeId(tmp)

  
PRI ResetSocket(id)
  Socket.Disconnect(id)                                                                                                                                 
  Socket.Close(id)
  
PRI IsolateTcpSocketById(id) | tmp
  tmp := |< id
  tcpMask &= tmp


PRI SetTcpSocketMaskById(id, state) | tmp
'' The tcpMask contains the socket the the StatusMonitor monitors
  tmp := |< id
  
  if(state == 1)
    tcpMask |= tmp
  else
    tmp := !tmp
    tcpMask &= tmp 
    
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' W5100 Helper methods
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI GetCommandRegisterAddress(id)
  return Socket#_S0_CR + (id * $0100)

PRI GetStatusRegisterAddress(id)
  return Socket#_S0_SR + (id * $0100)

    
PRI SetMac(_firstOctet)
  Socket.WriteMACaddress(true, _firstOctet)
  return 


PRI SetGateway(_firstOctet)
  Socket.WriteGatewayAddress(true, _firstOctet)
  return 


PRI SetSubnet(_firstOctet)
  Socket.WriteSubnetMask(true, _firstOctet)
  return 


PRI SetIP(_firstOctet)
  Socket.WriteIPAddress(true, _firstOctet)
  return 



PRI StringSend(id, _dataPtr)
  Socket.txTCP(id, _dataPtr, strsize(_dataPtr))
  return 


PRI SendChar(id, _dataPtr)
  Socket.txTCP(id, _dataPtr, 1)
  return 

 
PRI SendChars(id, _dataPtr, _length)
  Socket.txTCP(id, _dataPtr, _length)
  return 


PRI InitializeSocket(id)
  Socket.Initialize(id, TCP_PROTOCOL, port, remotePort, @remoteIp)
  return

PRI InitializeSocket2(id)
  Socket.Initialize(id, TCP_PROTOCOL, port2, remotePort, @remoteIp)
  return

PRI InitializeSocketForEmail(id)
  Socket.Initialize(id, TCP_PROTOCOL, port2, emailPort, @emailIp)
  return
  
PRI InitializeUDPSocket(id)
  Socket.Initialize(id, UDP_PROTOCOL, uport, remotePort, @remoteIp)
  return




''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Debug/Display Methods
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI QueueDump
  '' Display socket IDs in the queue
  '' ie 00000401 -> socket Zero is next to pop off
  PlxST.str(string("FIFO["))
  PlxST.dec(fifoSocketDepth)
  PlxST.str(string("] "))
  PlxST.hex(fifoSocket, 8)

    
PRI StackDump | clsd, open, lstn, estb, clwt, clng, id, ulst
  '' This method is purely for debugging
  '' It displays the status of all socket registers
  repeat until not lockset(debugSemId)
  clsd := closedState
  open := openState
  lstn := listenState
  estb := establishedState
  clwt := closeWaitState
  clng := closingState
  ulst := udpListen
  lockclr(debugSemId)

  PlxST.char(13) 
  repeat id from 3 to 0
    PlxST.dec(id)
    PlxST.str(string("-"))
    PlxST.hex(status[id], 2)
    PlxST.str(string(" "))
    pause(1)

  PlxST.str(string(13,"clsd open lstn estb clwt clng udps", 13))
  PlxST.bin(clsd, 4)
  PlxST.str(string("-"))
  PlxST.bin(open, 4)
  PlxST.str(string("-"))
  PlxST.bin(lstn, 4)
  PlxST.str(string("-"))  
  PlxST.bin(estb, 4)
  PlxST.str(string("-"))  
  PlxST.bin(clwt, 4)
  PlxST.str(string("-"))  
  PlxST.bin(clng, 4)
  PlxST.str(string("-"))  
  PlxST.bin(ulst, 4)
  PlxST.char(13)

   
PRI Pause(Duration)  
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> 381) + cnt)
  return


PRI StatusMonitor | id, tmp, value
'' StatusMonitor is the heartbeat of the project
'' Here we monitor the state of the Wiznet 5100's 4 sockets
  repeat

    Socket.GetStatus32(@status[0])

    ' Encode status register states
    repeat until not lockset(debugSemId)

    closedState := openState := listenState := establishedState := {
     } closeWaitState := closingState := 0
     
    repeat id from 0 to 3
      case(status[id])
        $00: closedState               |= |< id
             closedState               &= tcpMask  
        $13: openState                 |= |< id
             openState                 &= tcpMask                   
        $14: listenState               |= |< id
             listenState               &= tcpMask
        $17: establishedState          |= |< id
             establishedState          &= tcpMask
        $18,$1A,$1B: closingState      |= |< id
                     closingState      &= tcpMask
        $1C: closeWaitState            |= |< id
             closeWaitState            &= tcpMask
        $1D: closingState              |= |< id
             closingState              &= tcpMask
        $22: udpListen                 |= |< id
             udpListen                 &= udpMask 

    'Queue up socket IDs
    if(lastEstblState <> establishedState)
      value := establishedState
      repeat while value > 0
        tmp := DecodeId(value)
        if(tmp > -1)
          if(QueueSocket(tmp))
            tmp := |< tmp
            tmp := !tmp
            value &= tmp
          else
            quit
      lastEstblState := establishedState

    lockclr(debugSemId)
    
    ' Initialize a closed socket 
    if(closedState > 0)
      id := DecodeId(closedState)
      if(id > -1)
        InitializeSocket(id & tcpMask)
    
    'Start a listener on an initialized/open socket   
    if(openState > 0)
      id := DecodeId(openState)
      if(id > -1)
        Socket.Listen(id & tcpMask)

return
pub TmpStart | status1, temp1, crc

  
  ow.init(24)                                                    ' DS1820 on P24
  status1 := ow.reset                                            ' check for device
  
  if (status1 == %10)                                            ' good 1W reset
   readsn(@snum)                                               ' read the serial #
    showsn(@snum)                                               ' show it
    crc := ow.crc8(@snum, 7)                                    ' calculate CRC
    if (crc <> snum[7])                                         ' compare with CRC in SN
      PlxST.str(string("    "))
      PlxST.hex(crc, 2)
      PlxST.str(string(" - bad CRC"))
            
    else 
        temp1 := readtc                                          ' read the temperature
        PlxST.str(string(LF, LF, LF))
     '   showc(temp)                                             ' display in °C
        showf(temp1)                                             ' display in °F
      
  else
    case status
      %00 : PlxST.str(string("-- Buss short"))
      %01 : PlxST.str(string("-- Buss interference"))
      %11 : PlxST.str(string("-- No device"))


pub readsn(pntr)

'' Reads serial number from 1W device
'' -- stores in array at pntr

  ow.reset
  ow.write(RD_ROM)
  repeat 8
    byte[pntr++] := ow.read

  
pub showsn(pntr)

'' Displays 1W serial number stored in array at pntr

  PlxST.str(string("SN: "))
  pntr += 7                                                     ' move to MSB
  repeat 8
    PlxST.hex(byte[pntr--], 2)                                   ' print MSB to LSB, l-to-r
  PlxST.char(13)  
  

pub readtc | tc

'' Reads temperature from DS1820
'' -- returns degrees C in 0.1 degree units

  ow.reset               
  ow.write(SKIP_ROM)          
  ow.write(CVRT_TEMP)          
  repeat                                                        ' let conversion finish                 
    tc := ow.rdbit     
  until (tc == 1)    
  ow.reset               
  ow.write(SKIP_ROM)          
  ow.write(RD_SPAD)          
  tc := ow.read                                                 ' lsb of temp      
  tc |= ow.read << 8                                            ' msb of temp
  ow.reset

  tc := ~~tc * 5                                                ' extend sign, 0.1° units

  if (tc > 0)                                                   'Convert to °F
    tc := tc * 9 / 5 + 32_0
  else
    tc := 32_0 - (||tc * 9 / 5)

    
  return tc    

pub read_tca(snpntr) | tc, idx

'' Reads temperature from DS1822 at specific address
'' -- returns degrees C in 0.0001 degree units
'' -- snpntr is address of byte array with serial #

  ow.reset               
  ow.write(MATCH_ROM)                                           ' use serial #
  repeat idx from 0 to 7                                        ' send serial #
    ow.write(byte[snpntr][idx])          
  ow.write(CVRT_TEMP)                                           ' start conversion          
  repeat                                                        ' let conversion finish                 
    tc := ow.rdbit     
  until (tc == 1)    
  ow.reset               
  ow.write(MATCH_ROM)
  repeat idx from 0 to 7
    ow.write(byte[snpntr][idx])            
  ow.write(RD_SPAD)                                             ' read scratchpad     
  tc := ow.read                                                 ' lsb of temp      
  tc |= ow.read << 8                                            ' msb of temp

  tc := ~~tc * 5                                                ' extend sign, 0.1° units

  if (tc > 0)                                                   'Convert to °F
    tc := tc * 9 / 5 + 32_0
  else
    tc := 32_0 - (||tc * 9 / 5)                                             ' extend sign, 0.0001° units

  return tc

pub showf(temp) | tp

'' Print temperature in 0.1 degrees Fahrenheit
'' -- temp is passed in C

    
  if (temp < 0)
    PlxST.char("-")
    ||temp
    
  PlxST.dec(temp / 10)
  PlxST.char(".")
  PlxST.dec(temp // 10)
  PlxST.char(176)
  PlxST.char("F")  
  PlxST.char(CLREOL)
  PlxST.char(CR)  


pub getbit(val, bit)

  return (val & (|< bit)) >> bit 


PUB SetRTC '                 Set RTC
    PlxST.str(string("Set RTC", 13))
  '                          Open UDP socket
'≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈   .
  Socket.Initialize(socketf, UDP_PROTOCOL, TIME_PORT, 0, @remoteIp)
  
    PlxST.str(string("RTC 1", 13))
  Pause(200)  
    'check the status of the socket for connection and get internet time
    if ReadStatus(socketf) == Socket#_SOCK_UDP
    
       PlxST.str(string("RTC 2", 13))
       Pause(200)   '<-- Some Delay required here after socket connection
       if GetTime(0,@Buffer)
       
          PlxST.str(string("RTC 3", 13))
'                        Decode 64-Bit time from server           
'≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈       
          SNTP.GetTransmitTimestamp(Zone,@Buffer,@LongHIGH,@LongLOW)

'                         Set RTC to Internet Time          
'≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈
          RTC.SetDateTime(byte[@MM_DD_YYYY][3],   { <- Month
                        } byte[@MM_DD_YYYY][2],   { <- Day
                        } word[@MM_DD_YYYY][0]-2000,   { <- Year
                        } byte[@DW_HH_MM_SS][3],  { <- (day of week)
                        } byte[@DW_HH_MM_SS][2],  { <- Hour
                        } byte[@DW_HH_MM_SS][1],  { <- Minutes
                        } byte[@DW_HH_MM_SS][0])  { <- Seconds }

   PlxST.str(RTC.FmtDateTime)                
PUB GetTime(sockNum,BufferAddress)|i
    SNTP.CreateUDPtimeheader(BufferAddress,@timeIPaddr)
    Socket.txUDP(sockNum, BufferAddress) '<-- Send the UDP packet

    repeat 10*TIMEOUT_SECS
      i := Socket.rxUDP(sockNum,BufferAddress)  
      if i == 56
         Socket.Close(sockNum)  '<-- At this point we are done, we have
                                    '     the time data and don't need to keep
                                    '     the connection active.
         return 1                   '<- Time Data is ready
      Pause(100) '<- if 1000 = 1 sec ; 10 = 1/100th sec X 100 repeats above = 1 sec   
    return -1                       '<- Timed out without a response

PRI ReadStatus(socketNum) : socketStatus
    Socket.readIND((Socket#_S0_SR + (socketNum * $0100)), @socketStatus, 1)
PUB TempChecker | temp

repeat
       pause(1000)
       temp := read_tca(@DS1820SNBlack) {Read the temp in F°.}
       bytemove(@tmpt[23],STR.numberToDecimal(temp,4),4)
       PlxST.str(string("Black:"))
       PlXST.dec(temp)
       'showf(temp)
         
       SysTemp := (temp / 10)

      { temp := read_tca(@DS1820SNPanel) {Read the temp in F°.}
       bytemove(@tmpt[23],STR.numberToDecimal(temp,4),4)
       PlxST.str(string("Black:"))
       PlXST.dec(temp)}
       
       PlxST.char(13)

PUB IntInputs | SinA, SinB, idx

    expand1.out(SiA_add, 255) 
    SinA := expand1.in(SiA_add)
    expand1.out(SiB_add, 255) 
    SinB := expand1.in(SiB_add) 

    eStop  := 0
    PnlOPn := 0
    FlowSw := getbit(SinA, 5)
    
    AB[0]  := getbit(SinA, 2)
    AB[1]  := getbit(SinA, 1)
    AB[2]  := getbit(SinA, 0)
    
    CP[0]  := getbit(SinB, 7)
    CP[1]  := getbit(SinB, 6)
    CP[2]  := getbit(SinB, 5)
    CP[3]  := getbit(SinB, 4)
    RLY[0] := getbit(SinB, 3)  'D
    RLY[1] := getbit(SinB, 2)  'C
    RLY[2] := getbit(SinB, 1)  'B
    RLY[3] := getbit(SinB, 0)  'A
     

    
   
PUB ReadInputs | SinA, SinB, idx,  currentTimeL
      

    If CurrentTime => 2200
      CurrentTimeL := 2159
    Else
      currentTimeL := currentTime
      
    expand1.out(SiA_add, 255) 
    SinA := expand1.in(SiA_add)
    expand1.out(SiB_add, 255) 
    SinB := expand1.in(SiB_add)

   { PlxST.char(13)
    PlxST.Dec(SinA)
    PlxST.char(13)
    PlxST.Dec(Sinb)
    PlxST.char(13)   }
        
    eStop  := getbit(SinA, 7)
    PnlOPn := getbit(SinA, 6)
    FlowSw := getbit(SinA, 5)

    AB[0]  := getbit(SinA, 2)
    AB[1]  := getbit(SinA, 1)
    AB[2]  := getbit(SinA, 0)
    
    CP[0]  := getbit(SinB, 7)
    CP[1]  := getbit(SinB, 6)
    CP[2]  := getbit(SinB, 5)
    CP[3]  := getbit(SinB, 4)
    RLY[0] := getbit(SinB, 3)
    RLY[1] := getbit(SinB, 2)
    RLY[2] := getbit(SinB, 1)
    RLY[3] := getbit(SinB, 0)
    PlxST.char(13)

      If  FlowSw == 0
        bytemove(@flsw[23],@SMon,4)
      Else
         bytemove(@flsw[23],@SMoff,4)
         

    if eStop == 1
      Smode := 0
      Mode := 50
     
    If PnlOpn == 1  AND Smode <> 0
      Smode := 4
      Mode :=50
    Else
      If Smode == 4
        Smode := 1    
     

   IF Smode <> 0 AND Smode <> 4
      
    If AB[0] == 0
      ModeTime:= CurrentTimeL + 200 
      Smode := 2         
      Mode := 54
    
    If AB[1] == 0 
     If Blower == 0
       Blower := 1 
       Smode := 2
       ModeTime := CurrentTimeL + 200
     Else
       Blower := 0
 
    If AB[2] == 0 
      P41 := 1 - P41
      P42 := P41
      
    If CP[0] == 0 
      Smode := 1         
      Mode := 50

    If CP[1] == 0 
      ModeTime:= CurrentTimeL + 200 
      Smode := 2         
      Mode := 51

    If CP[2] == 0 
      ModeTime:= CurrentTimeL + 200 
      Smode := 2         
      Mode := 52
               
    If CP[3] == 0 
      ModeTime:= CurrentTimeL + 200 
      Smode := 2         
      Mode := 53
                           
    If RLY[0] == 0 
      Smode := 1         
      Mode := 50
       
    If RLY[1] == 0 
      ModeTime:= CurrentTimeL + 200 
      Smode := 2         
      Mode := 54
             
    If RLY[2] == 0 
      P41 := 0
      P42 := 0
            
    If RLY[3] == 0
      P41 := 1
      P42 := 1      

   repeat idx from 0 to 2
      ABo[idx] := AB[idx]   
      CPo[idx] := CP[idx]
                       
PUB Timer |  month, currentTimeL 
  repeat
       Pause(100)
       ReadInputs
       Pause(250)
           
       'PlxST.str(RTC.FmtDateTime)
       PlxST.char(13)                              
       PlxST.Dec(Smode)
       PlxST.char(13)
       PlxST.Dec(mode)
       PlxST.char(13)
     
           
       Month := RTC.GetMonth  
       Today := (RTC.getdayofweek)
       currentTimeL := (RTC.gethour) * 100     
       currentTime := currentTimeL + (RTC.getminutes)

       
       PlxST.Dec(currentTime)
       PlxST.char(13)
       
       
       If HtrEn == 1 AND ((SysTemp < SpaSP AND (Mode == 54 OR Mode == 57)) OR (SysTemp < PoolSP And (Mode == 53 OR Mode == 52)))
         HtrOn := 1
       Else
         HtrOn := 0
       
       If Smode == 2 AND ModeTime < CurrentTime
         Mode := 50
         Smode := 1
         Blower := 0
         P41 := P42 := 0
       Else
         If Smode == 2
         
      If Smode == 5 AND ModeTime < CurrentTime           'spa fill to spa run

        If CurrentTime => 2200
            ModeTime := 2359
        Else
           ModeTime := CurrentTime + 200
        Smode := 2         
        Mode := 54
         
      If SMode == 1 OR SMode == 3
        ontime  := PoolWSOnTime[Today]
        offtime := PoolWSOffTime[Today]
       
         IF currentTime > ontime AND currentTime < offtime
           PlxST.str(string("Pool w/Sweep On  "))
           Mode := 52
           Smode := 3
           IF SysTemp < SolarSP
              SolarEnable  := 1
           Else
              SolarEnable  := 0
           
         Else
                {
           ontime := SolarOnTime[Today]
           offtime:= SolarOffTime[Today]
            
           IF currentTime > ontime AND currentTime < offtime 'AND Month => 14   AND Month =< 19 AND SolarEnable  == 1     'April to Sept   
             PlxST.str(string("Solar On  "))
             Mode := 53
             Smode := 3
           Else  

             ontime := Solar2OnTime[Today]
             offtime:= Solar2OffTime[Today]
            
             IF currentTime > ontime AND currentTime < offtime AND Month => 4 AND Month =< 9 AND SolarEnable  == 1     'April to Sept   
               PlxST.str(string("Solar On  "))
               Mode := 51
               Smode := 3

             Else       }      
          
               ontime := SpaOnTime[Today]
               offtime:= SpaOffTime[Today]
            
               IF currentTime > ontime AND currentTime < offtime
                PlxST.str(string("Spa On  "))
                Mode := 55
                Smode := 3   
       
               Else                       
                 If Smode== 3
                  PlxST.str(string("System Idle "))
                  Mode := 50
                  Smode := 1  
       
    SetStatis
    WOut

  GotoTimer 

PUB SetButtons | CurrentTime2              'Toggle button state and dynamically change html code



       
      
 CurrentTime2 := currentTime
  If CurrentTime2 => 2200
      CurrentTime2 := 2158
 
 PlxST.str(string("-1-"))
 
   If SMode <> 0 AND SMode <> 4 
     If ButtonSelection == 50           'System idle
       Smode := 1         
       Mode := 50
        
    If ButtonSelection == 51            ' Pool W/O Sweep ON
       ModeTime:= CurrentTime2 + 200    ' 2 hr on time
       Smode := 2          
       Mode := 51
                 
    If ButtonSelection == 52            ' Pool W/ Sweep ON
       ModeTime:= CurrentTime2 + 200 
       Smode := 2            
       Mode := 52
                 
    If ButtonSelection == 53            ' Pool On W/ Heat
       ModeTime:= CurrentTime2 + 200 
       Smode := 2         
       Mode := 53
                
    If ButtonSelection == 54            ' Spa On W/ Heat
       ModeTime:= CurrentTime2 + 200 
       Smode := 2         
       Mode := 54   
                
    If ButtonSelection == 55            ' Spa On W/o Heat
       ModeTime:= CurrentTime2 + 20 
       Smode := 2         
       Mode := 55
       
    If ButtonSelection == 56            ' Solar Test
       ModeTime:= CurrentTime2 + 100 
       Smode := 2         
       Mode := 56  

    If ButtonSelection == 57            ' Lg Spa On W/ Heat      fill 30 min
       ModeTime:= CurrentTime2 + 5 
       Smode := 5            
       Mode := 57   

    If ButtonSelection == 58            ' Lg Spa On W/ Heat      Stay on
       ModeTime:= 2500 
       Smode := 2         
       Mode := 54
                 
    If ButtonSelection == 59            ' Pool W/ Sweep ON       Stay on
       ModeTime:= 2500 
       Smode := 2            
       Mode := 52   

    If ButtonSelection == 41            
      P41 := 1 - P41 

    If ButtonSelection == 42
      P42 := 1 - P42

    If ButtonSelection == 31
      P31 := 1 - P31


    If ButtonSelection == 32
      P32 := 1 - P32


    If ButtonSelection == 30
      P30 := 1 - P30
      
    If ButtonSelection == 20
      If SpaSP =< SpHl
        SpaSp :=( SpaSp + 1)
         
         
    If ButtonSelection == 21
      If SpaSP => SpLl
        SpaSp := (SpaSp - 1 )
        


  If ButtonSelection == 24 AND eStop == 0           'Reset E-stop
    Smode := 1         
    Mode := 50


  If ButtonSelection == 25           'E-stop
    Smode := 0         
    Mode := 50
  

  PlxST.char(13)
  PlxST.dec(Mode)
  PlxST.char(13)   
  PlxST.dec(SMode)
  PlxST.char(13)
  SetStatis
                
PUB SetStatis            ' Shift01 (R2,R1,No,S2.S1,P3,P2,P1) Shift02 (AX3,AX2,AX1,CL,SpaLt,PoolLt,Sweep,Heater)

  
    If ( Mode == 53 OR Mode == 52 )
      bytemove(@tmSp[23],STR.numberToDecimal((PoolSp*10),4),4) 
    ELSE
      bytemove(@tmSp[23],STR.numberToDecimal((SpaSp*10),4),4)
      PlxST.char(13)
      ' PlxST.dec(SpaSP)
  
  If SMode == 0
    bytemove(@sysm[23],@SMStop,6)
    
  If SMode == 1         
    bytemove(@sysm[23],@SMidle,6)
    
  If SMode == 2         
    bytemove(@sysm[23],@SMon,6)

  If SMode == 3         
    bytemove(@sysm[23],@SMauto,6)

  If SMode == 4         
    bytemove(@sysm[23],@SMman,6)                       

  If  P41 == 1
    Shift02 := Shift02 | %0000_0100
    bytemove(@pllt[23],@SMon,4)
  Else
    Shift02 := Shift02 & %1111_1011
    bytemove(@pllt[23],@SMoff,4)

  If  P42 == 1
    Shift02 := Shift02 | %0000_1000
    bytemove(@splt[23],@SMon,4)
  Else
    Shift02 := Shift02 & %1111_0111
    bytemove(@splt[23],@SMoff,4)
   
  If  P31 == 1
   Shift02 := Shift02 | %0010_0000
   bytemove(@aux1[23],@SMon,4)
  Else
    Shift02 := Shift02 & %1101_1111
   bytemove(@aux1[23],@SMoff,4)

  If  P32 == 1
   Shift02 := Shift02 | %0100_0000
   bytemove(@aux2[23],@SMon,4)
  Else
    Shift02 := Shift02 & %1011_1111
    bytemove(@aux2[23],@SMoff,4)
   
     
  If  P30 == 1
   Blower := 1
  Else
    Blower := 0
   
        
  If Mode == 50                  'System Idle
   '     bytemove(@sysm[23],@SMidle,6)
        bytemove(@mpmp[23],@SMoff,4)
        bytemove(@bpmp[23],@SMoff,4)
        bytemove(@spva[23],@SMpool,9)
        bytemove(@rtva[23],@SMpool,9)
        bytemove(@hter[23],@SMoff,4)
        HtrEn := 0
        Shift01 :=%0000_0000
        Shift02 := Shift02 & %1110_1100



  If Mode == 51                 ' Pool W/O Sweep ON
        bytemove(@mpmp[23],@SMon,4)
        bytemove(@bpmp[23],@SMoff,4)
        bytemove(@spva[23],@SMpool,9)
        bytemove(@rtva[23],@SMpool,9)
        bytemove(@hter[23],@SMoff,4)
        HtrEn := 0
        Shift01 :=  %0000_0100
        Shift02 := Shift02 & %1110_1101


  If Mode == 52                  ' Pool W/ Sweep ON
        bytemove(@mpmp[23],@SMon,4)
        bytemove(@bpmp[23],@SMon,4)
        bytemove(@spva[23],@SMpool,9)
        bytemove(@rtva[23],@SMpool,9)
        bytemove(@hter[23],@SMoff,4)
        HtrEn := 0
        Shift01 := %0000_0010
        Shift02 := Shift02 | %0001_0011 
   
  If Mode == 53                  ' Pool On W/ Heat 
        bytemove(@mpmp[23],@SMon,4)
        bytemove(@bpmp[23],@SMoff,4)    
        bytemove(@spva[23],@SMpool,9)
        bytemove(@rtva[23],@SMpool,9)  
        bytemove(@hter[23],@SMon,4)
        HtrEn := 1
        Shift01 := %0000_0010
        Shift02 := Shift02 & %1110_1101
   
  If Mode == 54                   ' Spa On W/ Heat 
        bytemove(@mpmp[23],@SMon,4)
        bytemove(@bpmp[23],@SMoff,4)     
        bytemove(@spva[23],@SMSspa,9)
        bytemove(@rtva[23],@SMSspa,9)
        bytemove(@hter[23],@SMon,4)
        HtrEn := 1
        Shift01 := %0100_1100
        Shift02 := Shift02 & %1110_1101

  If Mode == 55                     ' Spa On W/O Heat -  Fill 
        bytemove(@mpmp[23],@SMon,4)
        bytemove(@bpmp[23],@SMoff,4)
        bytemove(@spva[23],@SMLspa,9)
        bytemove(@rtva[23],@SMLspa,9)
        bytemove(@hter[23],@SMoff,4)
        HtrEn := 0
        Shift01 := %0000_1010
        Shift02 := Shift02 & %1111_1100  
        Shift02 := Shift02 | %0001_0000    

  If Mode == 56                 ' Pool W/ Solar
        bytemove(@mpmp[23],@SMon,4)
        bytemove(@bpmp[23],@SMoff,4)
        bytemove(@spva[23],@SMSolar,9)
        bytemove(@rtva[23],@SMpool,9)
        bytemove(@hter[23],@SMoff,4)
        HtrEn := 0
        Shift01 :=  %0000_0010
        Shift02 := Shift02 & %1110_1101  

  If Mode == 57                   ' Spa On W/ Heat  -  Fill
        bytemove(@mpmp[23],@SMon,4)
        bytemove(@bpmp[23],@SMoff,4)
        bytemove(@spva[23],@SMLspa,9)
        bytemove(@rtva[23],@SMpool,9)
        bytemove(@hter[23],@SMon,4)
        HtrEn := 1
        Shift01 := %0000_1100
        Shift02 := Shift02 & %1110_1101

  If  HtrOn == 1 AND HtrEN == 1 
    Shift02 := Shift02 | %0000_0001 
  Else
    Shift02 := Shift02 & %1111_1110

  If Blower == 1
    Shift02 := Shift02 | %1000_0000          
    bytemove(@blow[23],@SMon,4)    
  Else
    Shift02 := Shift02 & %0111_1111          
    bytemove(@blow[23],@SMoff,4)     

PUB WOut

  bytemove(@time1[0],RTC.FmtDateTime,25)

 
    
  If SMode == 0 OR SMode == 4
                                 ' Check if system is under manule operation
    expand1.out(SoA_add, 255)                                ' All outputs Off (High is off)
    expand1.out(SoB_add, 255)
    expand1.out(SoC_add, 255)
  Else
      expand1.out(SoA_add, (255-Shift01))                     'Set Outputs (Low is on, High is off)
      expand1.out(SoB_add, (255-Shift02))
      expand1.out(SoC_add, (255-Shift03))
      PLxST.char(13)
      PlxST.str(string("Output update"))
      PLxST.char(13)
      PlxST.dec(Shift01)
      PLxST.char(13)
      PlxST.dec(Shift02)
      PLxST.char(13)
      PlxST.dec(Shift03)
      PLxST.char(13)     
      
 
  return

CON
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial ions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}