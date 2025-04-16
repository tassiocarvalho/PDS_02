#include <avr/io.h>
#include <string.h>
#include <stdio.h>

// Configurações para o ATmega2560 a 16MHz
#define FOSC 16000000 // 16MHz Clock Speed
#define BAUD 9600
#define MYUBRR FOSC/16/BAUD-1

// Variáveis globais
uint16_t adcValue;

// Protótipos de funções
void USART_Init(unsigned int ubrr);
void USART_Transmit(unsigned char data);
void SendString(char mydata[]);
void InitADC(void);
uint16_t ReadADC(uint8_t ADCchannel);

int main(void)
{
    char valueStr[6]; // Buffer para armazenar o valor convertido
    
    // Inicialização
    USART_Init(MYUBRR);
    InitADC();
    
    // Loop principal
    while(1)
    {
        // Lê o sinal analógico no canal 0
        adcValue = ReadADC(0);
        
        // Calcula a tensão (0-5V) com 3 casas decimais
        // adcValue tem 10 bits (0-1023) -> 5V / 1023 * adcValue
        uint16_t voltage = (uint16_t)((5000.0 * adcValue) / 1023.0); 
        
        // Envia o valor pelo serial
        SendString("Tensao: ");
        sprintf(valueStr, "%d.%03d", voltage/1000, voltage%1000);
        SendString(valueStr);
        SendString(" V");
        
        // Adiciona quebra de linha
        USART_Transmit('\r');
        USART_Transmit('\n');
        
        // Pequeno delay para não sobrecarregar a serial
        // (aproximadamente 100 amostras por segundo, adequado para um sinal de 5Hz)
        for(volatile uint16_t i = 0; i < 5000; i++); 
    }
    
    return 0; // Nunca será atingido
}

// Inicializa o ADC
void InitADC(void)
{
    // Seleciona tensão de referência AVcc (5V)
    ADMUX = (1 << REFS0);
    
    // Define prescaler de 128 e habilita o ADC
    // Com clock de 16MHz, temos 16MHz/128 = 125kHz para o ADC (dentro da faixa ideal)
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
}

// Lê um canal do ADC
uint16_t ReadADC(uint8_t ADCchannel)
{
    // Seleciona o canal mantendo as configurações existentes
    ADMUX = (ADMUX & 0xF0) | (ADCchannel & 0x0F);
    
    // Inicia a conversão
    ADCSRA |= (1 << ADSC);
    
    // Aguarda a conclusão da conversão
    while(ADCSRA & (1 << ADSC));
    
    // Retorna o resultado da conversão (10 bits - 0 a 1023)
    return ADC;
}

// Inicializa a UART
void USART_Init(unsigned int ubrr)
{
    // Define o baud rate
    UBRR0H = (unsigned char)(ubrr >> 8);
    UBRR0L = (unsigned char)ubrr;
    
    // Habilita transmissor e receptor
    UCSR0B = (1 << RXEN0) | (1 << TXEN0);
    
    // Define formato: 8 bits de dados, 1 bit de parada
    UCSR0C = (3 << UCSZ00);
}

// Transmite um byte pela UART
void USART_Transmit(unsigned char data)
{
    // Espera o buffer de transmissão ficar vazio
    while(!(UCSR0A & (1 << UDRE0)));
    
    // Coloca o dado no buffer e transmite
    UDR0 = data;
}

// Transmite uma string pela UART
void SendString(char mydata[])
{
    for(int i = 0; i < strlen(mydata); i++)
    {
        USART_Transmit(mydata[i]);
    }
}