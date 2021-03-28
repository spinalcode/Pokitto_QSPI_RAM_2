uint32_t savePortMask=0;

#define SIZEOFRAM 1024 // 1024 for 128k, 512 for 64k

#define BYTEMODE 0
#define SEQMODE 64
#define PAGEMODE 128
#define DUALMODE 0x3B
#define QUADMODE 0x38
#define SPIMODE 0xFF

#define CLOCK 1<<6 // clock pin

#define SIO0 1<<20 // Also MOSI
#define SIO1 1<<21 // Also MISO
#define SIO2 1<<22 // 
#define SIO3 1<<23 // 


// SRAM pins 2 and 3 need to be high when in normal SPI mode
#define SET_SIO2 LPC_GPIO_PORT->SET[1] |= SIO2
#define SET_SIO3 LPC_GPIO_PORT->SET[1] |= SIO3

#define SET_CLOCK LPC_GPIO_PORT->SET[1] = CLOCK
#define CLR_CLOCK LPC_GPIO_PORT->CLR[1] = CLOCK
#define TOG_CLOCK ((volatile uint32_t *) 0xA0002304)[0] = CLOCK
#define TOG_CLOCK_NOP ((volatile uint32_t *) 0xA0002304)[0] = CLOCK; asm volatile ("nop\n");
//#define TOG_CLOCK LPC_GPIO_PORT->NOT[1] = CLOCK

#define TOG_CLOCK2 TOG_CLOCK; TOG_CLOCK
#define TOG_CLOCK4 TOG_CLOCK2; TOG_CLOCK2

#define SET_MOSI LPC_GPIO_PORT->SET[1] = SIO0
#define CLR_MOSI LPC_GPIO_PORT->CLR[1] = SIO0

#define GET_MISO (((volatile uint32_t *) 0xA0002104)[0] & SIO1) >> 21
#define SET_MASK_SIO LPC_GPIO_PORT->MASK[1] = (0x0F << 20); //mask P1_20...P1_23

DigitalOut SPI_CS(P1_5); // Select pin for the RAM chip

/*
   __ __
1-|  U  |-8
2-|     |-7
3-|     |-6
4-|_____|-5

1 - CS ------------------------ P1_5
2 - SIO1 - Slave Out (MISO) --- P1_21
3 - SIO2 - Slave Out 2 -------- P1_22
4 - VSS ----------------------- GND
5 - SIO0 - Slave In (MOSI) ---- P1_20
6 - SCK ----------------------- P1_6
7 - SIO3 - Slave Out 3 / Hold - P1_23
8 - VCC ----------------------- 3v3

Quad mode uses pins 5,2,3,7 for both in and output

Command	Function

0x01	Write MODE register
0x02	Write to memory address
0x03	Read from memory address
0x05	Read MODE register
0x38	Enter Quad I/O mode
0x3B	Enter Dual I/O mode
0xFF	Reset Dual and Quad mode (return to SPI?)

*/


void handOver(){

    LPC_GPIO_PORT->DIR[1] &= ~(1 << 5); // CS
    LPC_GPIO_PORT->DIR[1] &= ~(1 << 6); // CLOCK
    LPC_GPIO_PORT->DIR[1] &= ~(1 << 20); // SIO0
    LPC_GPIO_PORT->DIR[1] &= ~(1 << 21); // SIO1
    LPC_GPIO_PORT->DIR[1] &= ~(1 << 22); // SIO2
    LPC_GPIO_PORT->DIR[1] &= ~(1 << 23); // SIO3

//    LPC_GPIO_PORT->DIR[1] &= ~(0b111100000000000000110000);
}

void takeControl(){
//    LPC_GPIO_PORT->DIR[1] |= (0b111100000000000000110000);

    LPC_GPIO_PORT->DIR[1] |= (1 << 5); // CS
    LPC_GPIO_PORT->DIR[1] |= (1 << 6); // CLOCK
    LPC_GPIO_PORT->DIR[1] |= (1 << 20); // SIO0
    LPC_GPIO_PORT->DIR[1] |= (1 << 21); // SIO1
    LPC_GPIO_PORT->DIR[1] |= (1 << 22); // SIO2
    LPC_GPIO_PORT->DIR[1] |= (1 << 23); // SIO3

}


void setReadMode(){
    LPC_GPIO_PORT->DIR[1] &= ~(0x0f<<20);
    savePortMask = LPC_GPIO_PORT->MASK[1]; // save the mask
    LPC_GPIO_PORT->MASK[1] = ~(0x0f<<20); //mask P1_20...P1_23
}

void releaseReadMode(){
    LPC_GPIO_PORT->MASK[1] = savePortMask; // restor the mask    
}

void setWriteMode(){
    LPC_GPIO_PORT->DIR[1] |= (0x0f<<20);
    savePortMask = LPC_GPIO_PORT->MASK[1]; // save the mask
    LPC_GPIO_PORT->MASK[1] = ~(0x0f<<20); //mask P1_20...P1_23
}

void releaseWriteMode(){
    LPC_GPIO_PORT->MASK[1] = savePortMask; // restor the mask    
}

int spi_write(int value)
{

    uint8_t read = 0;
    for (int bit = 7; bit >= 0; --bit){

        if((value >> bit) & 0x01){ // Set MOSI Value
            SET_MOSI;
        }else{
            CLR_MOSI;
        }
        
        read |= (GET_MISO << bit); // Read MISO value
        TOG_CLOCK2; // Toggle the clock pin twice
    }

    return read;
}

/*
uint8_t readMode(){
    SPI_CS=0;
    spi_write(0x05);
    uint8_t currentMode = spi_write(0x00);
    SPI_CS=1;
    return currentMode;
}
*/

void setProtocol(uint8_t prot){

    SPI_CS=0;
    spi_write(prot);
    SPI_CS=1;
}

void setMode(uint8_t mode){
    switch(mode){
        case BYTEMODE:
        case PAGEMODE:
        case SEQMODE:
            SPI_CS=0;
            spi_write(0x01);
            spi_write(mode);
            SPI_CS=1;
            break;
    }
}

void writeToAddress(uint32_t address, const uint8_t* buffer, uint32_t number){
    SPI_CS=0;
    spi_write(0x02);
    uint8_t temp = address >> 16;
    spi_write(temp);
    temp = address >> 8;
    spi_write(temp);
    temp = address & 255;
    spi_write(temp);
    
    for(int t=0; t<number; t++){
        spi_write(buffer[t]);
    }
    SPI_CS=1;
}

void readFromAddress(uint32_t address, uint8_t* buffer, uint32_t number){
    SPI_CS=0;
    spi_write(0x03);
    uint8_t temp = address >> 16;
    spi_write(temp);
    temp = address >> 8;
    spi_write(temp);
    temp = address & 255;
    spi_write(temp);
    for(int t=0; t<number; t++){
        buffer[t] = spi_write(0x00); // sending dummy bytes will also read the MISO
    }
    SPI_CS=1;
}


inline void writeQuad(uint8_t value){

    LPC_GPIO_PORT->MPIN[1] = value << 16;
    TOG_CLOCK;
    TOG_CLOCK;
    LPC_GPIO_PORT->MPIN[1] = value << 20;
    TOG_CLOCK;
    TOG_CLOCK;
}

void readQuad(uint8_t* buffer, uint32_t number){
    unsigned int temp=0;

    #define read1pixel()\
        TOG_CLOCK;\
        temp = ((volatile uint32_t *) 0xA0002184)[0];\
        TOG_CLOCK_NOP;\
        temp = (temp >> 16);\
        TOG_CLOCK_NOP;\
        temp |= ((volatile uint32_t *) 0xA0002184)[0] >> 20;\
        TOG_CLOCK;\
        buffer[t++] = temp;
        

    #define read2pixel()\
        read1pixel(); read1pixel();

    #define read10pixel()\
        read2pixel(); read2pixel(); read2pixel(); read2pixel(); read2pixel();

    int t= -number;
    buffer+=number;

    while(t < -9){
        read10pixel();
    }
    
    for(; t;){
        read1pixel();
    }

}

void clearQuad(){
    setWriteMode();
    SPI_CS=0;
    writeQuad(0x02); // write command
    writeQuad(0); // First byte of address
    writeQuad(0); // Second byte of address
    #if SIZEOFRAM == 1024
        // 128k RAM
        writeQuad(0); // Third byte of address
        // with 24bit address there is extra to clear
        for(int t = 131071; t; --t){
            writeQuad(0);
        }
    #else
        // 64k RAM
        for(int t = 65535; t; --t){
            writeQuad(0);
        }
    #endif

    SPI_CS=1;
}

void writeToAddressQuad(uint32_t address, const uint8_t* buffer, uint32_t number){
    setWriteMode();
    SPI_CS=0;
    uint8_t temp;
    
    // max address in 128k RAM is 131071 or 000000011111111111111111 or 1FFFF
    address &= 131071;
    
    // 1 byte for the command, sent in 2 clock ticks
    writeQuad(0x02); // write command

    temp = (address >> 16) & 255;
    writeQuad(temp);
    temp = (address >> 8) & 255;
    writeQuad(temp);
    temp = address & 255;
    writeQuad(temp);
    
    // data sent in number*2 clock ticks
    for(int t=0; t<number; t++){
        writeQuad(buffer[t]);
    }
    
    releaseWriteMode();
    SPI_CS=1;
}

void readFromAddressQuad(uint32_t address, uint8_t* buffer, uint32_t number){
    takeControl();
    CLR_CLOCK;
    SPI_CS=0;
    uint8_t temp;
    setWriteMode();

    writeQuad(0x03); // read command
    
    temp = (address >> 16) & 255;
    writeQuad(temp);
    temp = (address >> 8) & 255;
    writeQuad(temp);
    temp = address & 255;
    writeQuad(temp);
    setReadMode();

    // pretend to read the first byte, its a dummy
    TOG_CLOCK_NOP;
    TOG_CLOCK_NOP;
    TOG_CLOCK_NOP;
    TOG_CLOCK_NOP;

    readQuad(&buffer[0], number);
    releaseReadMode();

    SPI_CS=1;
    handOver();
}

void initRAM(){
    // these pins need to be held high when using standard SPI mode
    SET_SIO2;
    SET_SIO3;

    // set clock pin to output
    LPC_GPIO_PORT->DIR[1] |= (1<<6);
    // set mosi pin to output
    LPC_GPIO_PORT->DIR[1] |= (1<<20);
    // set msio pin to input
    LPC_GPIO_PORT->DIR[1] &= ~(1 << 21);
    // set CS pin to output
    LPC_GPIO_PORT->DIR[1] |= (1<<5);

    // these use normal software spi
    setMode(SEQMODE);
    setProtocol(QUADMODE);

}
