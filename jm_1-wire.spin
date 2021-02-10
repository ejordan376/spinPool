'' =================================================================================================
''
''   File....... jm_1-wire.spin
''   Purpose.... Essential 1-Wire interface routines
''   Author..... Jon "JonnyMac" McPhalen (aka Jon Williams)
''               Copyright (c) 2009 Jon McPhalen
''               -- see below for terms of use
''   E-mail..... jon@jonmcphalen.com
''   Started.... 29 JUL 2009
''   Updated.... 01 AUG 2009 
''
'' =================================================================================================


var

  long  cog

  long  owcmd                                                   ' command to 1-Wire interface
  long  owio                                                    ' data in/out  


pub init(pin) | okay

'' Starts 1-Wire object

  finalize                                                      ' stop if already running

  if (pin => 0) and (pin =< 27)                                 ' protect rx, tx, i2c
    US_001   := clkfreq / 1_000_000                             ' initialize cog parameters
    owmask   := |< pin  
    cmdpntr  := @owcmd  
    iopntr   := @owio

  dira[pin] := 0                                                ' float OW pin
  owcmd := 0                                                    ' clear command                                                        
  okay := cog := cognew(@onewire, 0) + 1                        ' start cog

  return okay


pub finalize

'' Stops 1-Wire driver; frees a cog 

  if cog
    cogstop(cog~ - 1)


pub reset

'' Resets 1-Wire buss; returns buss status
''
''   %00 = buss short
''   %01 = bad response; possible interference on buss
''   %10 = good buss & presence detection
''   %11 = no device 

  iopntr := 0
  owcmd := 1
  repeat while owcmd

  return owio


pub write(b)

'' Write byte b to 1-Wire buss

  owio := b & $FF
  owcmd := 2
  repeat while owcmd


pub read

'' Reads byte from 1-Wire buss

  owio := 0
  owcmd := 3
  repeat while owcmd

  return owio & $FF


pub rdbit

'' Reads bit from 1-Wire buss
'' -- useful for monitoring device busy status

  owio := 0
  owcmd := 4
  repeat while owcmd

  return owio & 1


pub crc8(pntr, n)

'' Returns CRC8 of n bytes at pntr
'' -- interface to PASM code by Cam Thompson

  owio := pntr
  owcmd := (n << 8) + 5                                         ' pack count into command
  repeat while owcmd

  return owio


PUB crc8x(pntr, n) | crc, b

'' Returns CRC8 of n bytes at pntr
'' -- code by Micah Dowty

  crc := 0
  repeat n
    b := byte[pntr++]
    repeat 8
      if (crc ^ b) & 1
        crc := (crc >> 1) ^ $8C
      else
        crc >>= 1
      b >>= 1  

  return crc


dat

                        org     0

onewire                 andn    outa, owmask                    ' float buss pin
                        andn    dira, owmask                        

owmain                  rdlong  tmp1, cmdpntr           wz      ' get command
                if_z    jmp     #owmain                         ' wait for valid command
                        mov     bytecount, tmp1                 ' make copy (for crc byte count)
                        and     tmp1, #$FF                      ' strip off count 
                        max     tmp1, #6                        ' truncate command 

                        add     tmp1, #owcommands               ' add cmd table base
                        jmp     tmp1                            ' jump to command handler

owcommands              jmp     #owbadcmd                       ' place holder
owcmd1                  jmp     #owreset
owcmd2                  jmp     #owwrbyte
owcmd3                  jmp     #owrdbyte
owcmd4                  jmp     #owrdbit
owcmd5                  jmp     #owcalccrc
owcmd6                  jmp     #owbadcmd

owbadcmd                wrlong  ZERO, cmdpntr                   ' clear command
                        jmp     #owmain                        
                

' -----------------
' Reset 1-Wire buss
' -----------------
'
' %00 = buss short
' %01 = bad response; possible interference on buss
' %10 = good buss & presence detection
' %11 = no device

owreset                 mov     value, #%11                     ' assume no device
                        mov     usecs, #480                     ' reset pulse
                        or      dira, owmask                    ' buss low                    
                        call    #pauseus
                        andn    dira, owmask                    ' release buss
                        mov     usecs, #5
                        call    #pauseus
                        test    owmask, ina             wc      ' sample for short, 1W -> C
                        muxc    value, #%10                     ' C -> value.1
                        mov     usecs, #65
                        call    #pauseus
                        test    owmask, ina             wc      ' sample for presence, 1W -> C
                        muxc    value, #%01                     ' C -> value.0                        
                        mov     usecs, #410
                        call    #pauseus
                        wrlong  value, iopntr                   ' update hub
                        wrlong  ZERO, cmdpntr
                        jmp     #owmain                          
                        

' -------------------------
' Write byte to 1-Wire buss
' -------------------------
'
owwrbyte                rdlong  value, iopntr                   ' get byte from hub
                        mov     bitcount, #8                    ' write 8 bits
wrloop                  shr     value, #1               wc      ' value.0 -> C, value >>= 1
                if_c    mov     usecs, #6                       ' write 1
                if_nc   mov     usecs, #60                      ' write 0
                        or      dira, owmask                    ' pull buss low 
                        call    #pauseus
                        andn    dira, owmask                    ' release buss
                if_c    mov     usecs, #64                      ' pad for 1
                if_nc   mov     usecs, #10                      ' pad for 0
                        call    #pauseus
                        djnz    bitcount, #wrloop               ' all bits done?
                        wrlong  ZERO, cmdpntr                   ' yes, update hub
                        jmp     #owmain


' --------------------------
' Read byte from 1-Wire buss
' --------------------------
'
owrdbyte                mov     bitcount, #8                    ' read 8 bits
                        mov     value, #0                       ' clear workspace
rdloop                  mov     usecs, #6
                        or      dira, owmask                    ' buss low 
                        call    #pauseus
                        andn    dira, owmask                    ' release buss
                        mov     usecs, #9                       ' hold-off before sample
                        call    #pauseus
                        test    owmask, ina             wc      ' sample buss, 1W -> C
                        shr     value, #1                       ' value >>= 1
                        muxc    value, #%1000_0000              ' C -> value.7
                        mov     usecs, #55                      ' finish read slot
                        call    #pauseus                          
                        djnz    bitcount, #rdloop               ' all bits done?
                        wrlong  value, iopntr                   ' yes, update hub
                        wrlong  ZERO, cmdpntr                       
                        jmp     #owmain


' -------------------------
' Read bit from 1-Wire buss
' -------------------------
'
owrdbit                 mov     value, #0                       ' clear workspace
                        mov     usecs, #6
                        or      dira, owmask                    ' buss low 
                        call    #pauseus
                        andn    dira, owmask                    ' release buss
                        mov     usecs, #9                       ' hold-off before sample
                        call    #pauseus
                        test    owmask, ina             wc      ' sample buss, 1W -> C 
                        muxc    value, #1                       ' C -> value.0                        
                        mov     usecs, #55                      ' finish read slot
                        call    #pauseus
                        wrlong  value, iopntr                   ' update hub
                        wrlong  ZERO, cmdpntr                       
                        jmp     #owmain


' -------------------------------
' Calculate CRC8
' * original code by Cam Thompson 
' -------------------------------
'
owcalccrc               mov     value, #0                       ' clear workspace 
                        shr     bytecount, #8           wz      ' clear command from count
                if_z    jmp     #savecrc
                        rdlong  hubpntr, iopntr                 ' get address of array

crcbyte                 rdbyte  tmp1, hubpntr                   ' read byte from array
                        add     hubpntr, #1                     ' point to next
                        mov     bitcount, #8
                        
crcbit                  mov     tmp2, tmp1                      ' x^8 + x^5 + x^4 + 1  
                        shr     tmp1, #1
                        xor     tmp2, value
                        shr     value, #1
                        shr     tmp2, #1                wc
                if_c    xor     value, #$8C
                        djnz    bitcount, #crcbit
                        djnz    bytecount, #crcbyte

savecrc                 wrlong  value, iopntr                   ' update hub
                        wrlong  ZERO, cmdpntr                       
                        jmp     #owmain                


' ---------------------
' Pause in microseconds
' ---------------------
' 
pauseus                 mov     ustimer, US_001                 ' set timer for 1us
                        add     ustimer, cnt                    ' sync with system clock
usloop                  waitcnt ustimer, US_001                 ' wait and reload
                        djnz    usecs, #usloop                  ' update delay count
pauseus_ret             ret


' --------------------------------------------------------------------------------------------------

ZERO                    long    0

US_001                  long    0-0                             ' ticks per us

owmask                  long    0-0                             ' pin mask for 1-Wire pin
cmdpntr                 long    0-0                             ' hub address of command
iopntr                  long    0-0                             ' hub address of io byte

value                   res     1 
bitcount                res     1
bytecount               res     1
hubpntr                 res     1
usecs                   res     1
ustimer                 res     1

tmp1                    res     1
tmp2                    res     1

                        fit     492
                        

dat

{{

  Copyright (c) 2009 Jon McPhalen (aka Jon Williams)

  Permission is hereby granted, free of charge, to any person obtaining a copy of this
  software and associated documentation files (the "Software"), to deal in the Software
  without restriction, including without limitation the rights to use, copy, modify,
  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to the following
  conditions:

  The above copyright notice and this permission notice shall be included in all copies
  or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
  PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
  OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

}}                   