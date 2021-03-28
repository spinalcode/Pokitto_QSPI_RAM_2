
/*
This code uses software QSPI and manages 45FPS
*/

#include <Pokitto.h>

#include "globals.h"
#include "font.h"
#include "buttonhandling.h"
#include "ram.i"
#include "screen.h"

DigitalIn ESP_BUSY(EXT0);
DigitalOut LPC_BUSY(EXT1);

#define SET_LPC_BUSY LPC_BUSY.write(1)
#define CLR_LPC_BUSY LPC_BUSY.write(0)


// print text
void myPrint(char x, char y, const char* text) {
  uint8_t numChars = strlen(text);
  uint8_t x1 = 0;//2+x+28*y;
  for (uint8_t t = 0; t < numChars; t++) {
    uint8_t character = text[t] - 32;
    Pokitto::Display::drawSprite(x+((x1++)*8), y, font88[character]);
  }
}

char tempText[64];

int main(){
    using PC=Pokitto::Core;
    using PD=Pokitto::Display;
    using PB=Pokitto::Buttons;
    using PS=Pokitto::Sound;

    PC::begin();
    PD::invisiblecolor = 0;
    PD::adjustCharStep = 0;
    PD::adjustLineStep = 0;
    PD::persistence = 1;

    PD::load565Palette(websafe_pal);
    PD::lineFillers[0] = myBGFiller; // A custom filler to draw from SRAM HAT to screen

//    takeControl();
//    initRAM();
    handOver();
    LPC_BUSY.write(0);


  int howMany = 8;
  uint8_t myArray2[howMany];
  readFromAddressQuad(0, myArray2, howMany);


    while( PC::isRunning() ){


        sprintf(tempText,"FPS:%d",fpsCount);
        myPrint(0,8,tempText);
        sprintf(tempText,"BUSY:%d",ESP_BUSY.read());
        myPrint(0,16,tempText);

        fpsCounter++;
        frameCount++;

        if(PC::getTime() >= lastMillis+100){

            if(ESP_BUSY.read()==0){
                SET_LPC_BUSY;
                PC::update();
                CLR_LPC_BUSY;
            }

            lastMillis = PC::getTime();
            fpsCount = fpsCounter;
            fpsCounter = 0;
        }

    }
    
    return 0;
}
