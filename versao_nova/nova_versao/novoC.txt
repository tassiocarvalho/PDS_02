const byte adcPin = 0; // A0 <= ATMega 2560 A0 pin for ADC0
const int MAX_RESULTS = 3072; // Tamanho para armazenar 1023 amostras na subida e 1023 na descida
volatile uint16_t results [MAX_RESULTS]; // Vetor de dados
volatile int resultNumber;
volatile bool bufferFull = false;

volatile uint16_t prev_value = 0;
volatile bool waiting_for_reset = true;

ISR (ADC_vect)
{
  uint16_t current_value = ADC;

  // Se não estiver esperando um 0 (waiting_for_reset) e já tiver algo no vetor results
  if (!waiting_for_reset && resultNumber > 0) {
    int16_t diff = abs((int16_t)current_value - (int16_t)prev_value);

    // if (diff > 5) {
    //   // Passa a esperar por um reset (valor 0)
    //   waiting_for_reset = true;
    // }
  }

  // esperando por um reset e o valor atual é 0 (ou próximo de 0)
  if (waiting_for_reset && current_value <= 2) {
    resultNumber = 0;
    waiting_for_reset = false;
  }

  // Apenas armazenar o valor se não estamos esperando por um reset
  if (!waiting_for_reset) {
    // verifica se o buffer está cheio
    if (resultNumber >= MAX_RESULTS) {
      resultNumber = 0;
      bufferFull = true;
    }
    results[resultNumber++] = current_value;
    prev_value = current_value;
  }
}

EMPTY_INTERRUPT (TIMER1_COMPB_vect);

// Inicialização e configuração do ADC
void ADC_init() {
  ADCSRA = bit (ADEN) | bit (ADIE) | bit (ADIF); // Liga o ADC, habilita interrupção ao completar
  // Para 10 bits de resolução (1023 níveis), mantemos a configuração padrão
  //ADCSRA |= bit(ADPS2); // Prescaler de 16
  //ADCSRA |= bit(ADPS2) | bit(ADPS0); // Prescaler de 32
  //ADCSRA |= bit(ADPS1) | bit(ADPS0); // Prescaler de 8
  ADCSRA |= bit(ADPS2) | bit(ADPS1); // Prescaler de 64  16MHz/64 = 250khz => Tconv = 13/250kHz = 52us = 19236_SPS
  //ADCSRA |= bit (ADPS2) | bit (ADPS1) | bit (ADPS0); //Prescaler de 128
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
  TCCR1B = bit (CS11) |bit (WGM12); // CTC, prescaler de 8
  //TCCR1B = bit (CS11) | bit (CS10)  |bit (WGM12); // CTC, prescaler de 64
  TIMSK1 = bit (OCIE1B); // Habilita interrupção do Timer Compare Match B

  // Cálculo: (16MHz)/ (8 * 10230) - 1 = 194
  OCR1A = 195;
  OCR1B = 195; // Mesma frequência de amostragem
}

// Setup e execução
void setup() {
  Serial.begin(115200); // Alta velocidade para o Serial
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
      //delayMicroseconds(100);
    }

    bufferFull = false;
    interrupts();
  }
}
