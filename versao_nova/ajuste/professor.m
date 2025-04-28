%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%TEC513-MI de PDS-UEFS 2025.1
%Problema 02
%Arquivo para teste na recepção de dados pela USB
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%% LIMPA E FECHA TUDO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc;                           %limpa a tela do octave
clear all;                     %limpa todas as variáveis do octave
close all;                     %fecha todas as janelas

%%%%%%%%%%%%%%%%%%% CHAMADA DAS BIBLIOTECAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pkg load signal                %biblioteca para processamento de sinais
pkg load instrument-control    %biblioteca para comunicação serial

%%%%%%%%%%%%%%%%%%% ALOCAÇÃO DE VARIÁVEIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
MAX_RESULTS = 2048;            % Mesmo valor definido no Arduino
fs = 10230;                    % Frequência de amostragem do ADC no Arduino
amostras = 2048;               % Quantidade de amostras para visualizar
raw = [];                      % Variável para armazenar os dados recebidos pela USB

%%%%%%%%%%%%%%%%%%% ABERTURA DA PORTA SERIAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
s1 = serial("COM5");           % Porta COM5 conforme solicitado
set(s1, 'baudrate', 115200);   % Mesma velocidade configurada no Arduino (115200)
set(s1, 'bytesize', 8);        % 8 bits de dados
set(s1, 'parity', 'n');        % Sem paridade ('y' 'n')
set(s1, 'stopbits', 1);        % 1 bit de parada (1 ou 2)
set(s1, 'timeout', 200);       % Tempo ocioso sem conexão 20.0 segundos
srl_flush(s1);                 % Limpa buffer serial
pause(1);                      % Espera 1 segundo antes de ler dados

%%%%%%%%%%%%%%%%%%% LEITURA DA MENSAGEM INICIAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
i = 1;                         % Primeiro índice de leitura
t = [];                        % Inicializa array para armazenar bytes
while(1)                       % Espera para ler a mensagem inicial
    t(i) = srl_read(s1, 1);    % Lê as amostras de uma em uma
    if (t(i) == 10)            % Se for lido um enter (10 em ASCII)
        break;                 % Sai do loop
    endif
    i = i + 1;                 % Incrementa o índice de leitura
end
c = char(t);                   % Transformando caracteres recebidos em string
printf('recebido: %s', c);     % Imprime na tela do octave o que foi recebido

%%%%%%%%%%%%%%%%%%% CAPTURA DAS AMOSTRAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure(1);                     % Cria uma figura
tic;                           % Captura do tempo inicial

% Loop para adquirir dados continuamente
data = [];
for i = 1:MAX_RESULTS
    % Lê uma linha completa (até encontrar o caractere de nova linha)
    line = '';
    byte = 0;
    while (byte != 10)  % ASCII 10 = nova linha
        byte = srl_read(s1, 1);
        if (byte != 10)
            line = [line, char(byte)];
        endif
    end

    % Converte a string para número e adiciona ao array de dados
    if (length(line) > 0)
        data(i) = str2num(line);
    else
        data(i) = 0;  % Valor padrão se a linha estiver vazia
    endif

    % Sai do loop se tiver coletado amostras suficientes
    if (i >= amostras)
        break;
    endif
end

raw = data;                    % Armazena o dado bruto
time = (0:length(raw)-1)/fs;   % Vetor de tempo normalizado (em segundos)

% Plotando as figuras
subplot(3,1,1);
plot(time, raw*5/1023);        % Converte os valores ADC para tensão (0-5V)
xlabel('t(s)');
ylabel('Tensão (V)');
title('Sinal gerado x(t)');
grid on;

subplot(3,1,2);
stem(raw);                     % Plota amostras discretas
xlabel('n');
ylabel('Valor ADC');
title('x[n]');
grid on;

subplot(3,1,3);
stairs(raw);                   % Plota amostras regulares em forma de escada
xlabel('n');
ylabel('Valor ADC');
title('x[n] segurado');
grid on;

toc;                           % Captura do tempo final

%%%%%%%%%%%%%%%%%%% FECHA A PORTA DE COMUNICAÇÃO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fclose(s1);
