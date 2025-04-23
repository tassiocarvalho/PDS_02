#include <avr/io.h>
#include <avr/interrupt.h>

// Configurações para o ATmega2560
#define FOSC 16000000     // Clock 16MHz
#define BAUD 1000000      // Baud rate 1Mbps para transmissão rápida
#define MYUBRR (FOSC/16/BAUD-1)

// Protótipos de funções
void USART_Init(unsigned int ubrr);
void USART_Transmit(unsigned char data);
void InitADC(void);
uint16_t ReadADC(uint8_t ADCchannel);

int main(void)
{
    uint16_t adcValue;
    uint8_t highByte, lowByte;
    
    // Inicialização dos periféricos
    USART_Init(MYUBRR);
    InitADC();
    
    // Loop principal
    while(1)
    {
        // Leitura do ADC no canal 0
        adcValue = ReadADC(0);
        
        // Separar o valor de 16 bits em dois bytes para transmissão
        highByte = (adcValue >> 8) & 0xFF;  // Byte alto (bits 8-15)
        lowByte = adcValue & 0xFF;          // Byte baixo (bits 0-7)
        
        // Transmitir ambos os bytes
        USART_Transmit(highByte);
        USART_Transmit(lowByte);
        
        // Sem delay para máxima taxa de amostragem
    }
    
    return 0;
}

// Inicializa o ADC para máxima taxa de amostragem
void InitADC(void)
{
    // Seleciona tensão de referência AVcc (5V)
    ADMUX = (1 << REFS0);
    
    // Configura prescaler para 16 (menor valor prático para precisão adequada)
    // Com clock de 16MHz, temos 16MHz/16 = 1MHz para o ADC
    // Cada conversão leva ~13 ciclos, então taxa teórica é ~76.9kHz
    // Na prática, considerando overhead, chegamos a ~15kSPS
    ADCSRA = (1 << ADEN) | (1 << ADPS2);
}

// Lê um valor do ADC no canal especificado
uint16_t ReadADC(uint8_t ADCchannel)
{
    // Seleciona o canal mantendo as configurações de referência
    ADMUX = (ADMUX & 0xF0) | (ADCchannel & 0x0F);
    
    // Inicia a conversão
    ADCSRA |= (1 << ADSC);
    
    // Aguarda a conversão finalizar
    while(ADCSRA & (1 << ADSC));
    
    // Retorna o resultado (10 bits - 0 a 1023)
    return ADC;
}

// Inicializa a UART
void USART_Init(unsigned int ubrr)
{
    // Define o baud rate
    UBRR0H = (unsigned char)(ubrr >> 8);
    UBRR0L = (unsigned char)ubrr;
    
    // Habilita apenas o transmissor para máxima velocidade
    UCSR0B = (1 << TXEN0);
    
    // Define formato: 8 bits de dados, 1 bit de parada
    UCSR0C = (3 << UCSZ00);
}

// Transmite um byte pela UART
void USART_Transmit(unsigned char data)
{
    // Aguarda buffer de transmissão ficar vazio
    while(!(UCSR0A & (1 << UDRE0)));
    
    // Envia o dado
    UDR0 = data;
}