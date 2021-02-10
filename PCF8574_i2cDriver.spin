'PCF8574 I2C 8-Bit I/O Expansion Driver
'Copyright 2007 Raymond Allen   
'This is a stripped down version of Michael Green's "Basic_i2c_driver" found on "Object Exchange"
'It only reads and writes bytes
'It is coded to use pins 28 and 29, which are used by the Prop at boot time to access the EEPROM
'
'WARNING:  You should set all pins to HIGH (i.e., call OUT(255)) before using pins as inputs.  Otherwise, an input signal to a pin may be connected to ground and fry the chip!
'           (but, note that all pins HIGH is the power-on state)

'This is all in SPIN, so it doesn't use up a cog.


CON
   ACK      = 0                        ' I2C Acknowledge
   NAK      = 1                        ' I2C No Acknowledge
   Xmit     = 0                        ' I2C Direction Transmit
   Recv     = 1                        ' I2C Direction Receive
   SCL      = 28             'I2C clock pin#
   SDA      = 29             'I2C data pin#
   

PUB IN(address):data|ackbit
    START
    ackbit:=Write((address<<1)+1)
    if (ackbit==ACK)
      data:=Read(ACK)
    else
      data:=-1   'return negative to indicate read failure
    STOP
    return data
    

PUB OUT(address,data):ackbit
   START
   ackbit:=Write(address<<1)
   ackbit := (ackbit << 1) | Write(data)
   STOP
   return (ackbit==ACK)
            

PUB Start'(SCL) | SDA                   ' SDA goes HIGH to LOW with SCL HIGH
   outa[SCL]~~                         ' Initially drive SCL HIGH
   dira[SCL]~~
   outa[SDA]~~                         ' Initially drive SDA HIGH
   dira[SDA]~~
   outa[SDA]~                          ' Now drive SDA LOW
   outa[SCL]~                          ' Leave SCL LOW
  
PUB Stop'(SCL) | SDA                    ' SDA goes LOW to HIGH with SCL High
   outa[SCL]~~                         ' Drive SCL HIGH
   outa[SDA]~~                         '  then SDA HIGH
   dira[SCL]~                          ' Now let them float
   dira[SDA]~                          ' If pullups present, they'll stay HIGH

PUB Write(data) : ackbit '(SCL, data) : ackbit | SDA
'' Write i2c data.  Data byte is output MSB first, SDA data line is valid
'' only while the SCL line is HIGH.  Data is always 8 bits (+ ACK/NAK).
'' SDA is assumed LOW and SCL and SDA are both left in the LOW state.
   ackbit := 0 
   data <<= 24
   repeat 8                            ' Output data to SDA
      outa[SDA] := (data <-= 1) & 1
      outa[SCL]~~                      ' Toggle SCL from LOW to HIGH to LOW
      outa[SCL]~
   dira[SDA]~                          ' Set SDA to input for ACK/NAK
   outa[SCL]~~
   ackbit := ina[SDA]                  ' Sample SDA when SCL is HIGH
   outa[SCL]~
   outa[SDA]~                          ' Leave SDA driven LOW
   dira[SDA]~~

PUB Read(ackbit):data'(SCL, ackbit): data | SDA
'' Read in i2c data, Data byte is output MSB first, SDA data line is
'' valid only while the SCL line is HIGH.  SCL and SDA left in LOW state.
   data := 0
   dira[SDA]~                          ' Make SDA an input
   repeat 8                            ' Receive data from SDA
      outa[SCL]~~                      ' Sample SDA when SCL is HIGH
      data := (data << 1) | ina[SDA]
      outa[SCL]~
   outa[SDA] := ackbit                 ' Output ACK/NAK to SDA
   dira[SDA]~~
   outa[SCL]~~                         ' Toggle SCL from LOW to HIGH to LOW
   outa[SCL]~
   outa[SDA]~                          ' Leave SDA driven LOW


{  'I don't think we need this as Prop must have already initialized the I2C bus on Pins 28,29
PUB Initialize'(SCL) | SDA              ' An I2C device may be left in an
   outa[SCL] := 1                       '   reinitialized.  Drive SCL high.
   dira[SCL] := 1
   dira[SDA] := 0                       ' Set SDA as input
   repeat 9
      outa[SCL] := 0                    ' Put out up to 9 clock pulses
      outa[SCL] := 1
      if ina[SDA]                      ' Repeat if SDA not driven high
         quit                          '  by the EEPROM
}
 