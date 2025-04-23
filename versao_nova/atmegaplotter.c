const byte adcPin = 0; // A0 <= ATMega 2560 A0 pin for ADC0
const int MAX_RESULTS = 2046; // Tamanho para armazenar 1023 amostras na subida e 1023 na descida
volatile int results [MAX_RESULTS]; // Vetor de dados
volatile int resultNumber;
volatile bool bufferFull = false;

// ADC complete ISR
ISR (ADC_vect)
{
  if (resultNumber >= MAX_RESULTS) {
    resultNumber = 0;
    bufferFull = true;
  }
  results[resultNumber++] = ADC;
} // end of ADC_vect

EMPTY_INTERRUPT (TIMER1_COMPB_vect);

// Inicialização e configuração do ADC
void ADC_init() {
  ADCSRA = bit (ADEN) | bit (ADIE) | bit (ADIF); // Liga o ADC, habilita interrupção ao completar
  // Para 10 bits de resolução (1023 níveis), mantemos a configuração padrão
  ADCSRA |= bit (ADPS2) | bit (ADPS1) | bit (ADPS0); // Prescaler de 128 - adequado para conversão de 10 bits
  ADMUX = bit (REFS0) | (adcPin & 7); // Define a referência de tensão para Avcc (5V)
  ADCSRB = bit (ADTS0) | bit (ADTS2); // Timer/Counter1 Compare Match B
  ADCSRA |= bit (ADATE); // Liga o disparo automático
}

// Configuração do timer para amostragem
void timer(){
  // Reset do Timer 1
  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1 = 0;
  
  // Para frequência de amostragem de ~10.230 Hz (para sinal de 5Hz com 2046 amostras por ciclo)
  TCCR1B = bit (CS11) | bit (WGM12); // CTC, prescaler de 8
  TIMSK1 = bit (OCIE1B); // Habilita interrupção do Timer Compare Match B
  
  // Cálculo: 16MHz / (8 * 10230) - 1 = 195 (aproximadamente)
  OCR1A = 195; 
  OCR1B = 195; // Mesma frequência de amostragem
}

// Setup e execução
void setup() {
  Serial.begin(2000000); // Alta velocidade para o Serial
  timer();
  ADC_init();
  resultNumber = 0;
}

void loop() {
  // Quando o buffer estiver cheio, envie os dados para o Serial Plotter
  if (bufferFull) {
    // Desabilita interrupções enquanto envia dados
    noInterrupts();
    
    // Enviando para o Serial Plotter - precisa apenas enviar valores
    for (int i = 0; i < MAX_RESULTS; i++) {
      Serial.println(results[i]);
      // Um pequeno delay para não sobrecarregar o buffer serial
      delayMicroseconds(100);
    }
    
    bufferFull = false;
    interrupts();
  }
}