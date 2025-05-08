
clc;                           %limpa a tela do octave
clear all;                     %limpa todas as variáveis do octave
close all;                     %fecha todas as janelas

%%%%%%%%%%%%%%%%%%% CHAMADA DAS BIBLIOTECAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pkg load signal                %biblioteca para processamento de sinais
pkg load instrument-control    %biblioteca para comunicação serial

%%%%%%%%%%%%%%%%%%% ALOCAÇÃO DE VARIÁVEIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
MAX_RESULTS = 2048;            % Mesmo valor definido no Arduino
fs = 10230;                    % Frequência de amostragem do ADC no Arduino
amostras = 4096;                % Quantidade de amostras para visualizar
raw = [];                      % Variável para armazenar os dados recebidos pela USB

%%%%%%%%%%%%%%%%%%% ABERTURA DA PORTA SERIAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
s1 = serial("COM5");           % Porta COM5 conforme solicitado
set(s1, 'baudrate', 115200);   % Mesma velocidade configurada no Arduino (115200)
set(s1, 'bytesize', 8);        % 8 bits de dados
set(s1, 'parity', 'n');        % Sem paridade ('y' 'n')
set(s1, 'stopbits', 1);        % 1 bit de parada (1 ou 2)
set(s1, 'timeout', 1);         % Tempo ocioso reduzido para 1 segundo
srl_flush(s1);                 % Limpa buffer serial
pause(1);                      % Espera 1 segundo antes de ler dados

%%%%%%%%%%%%%%%%%%% LEITURA DA MENSAGEM INICIAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Corrigido: Pré-alocação do array t
t = zeros(1, 100);             % Pré-aloca com tamanho suficiente
i = 1;                         % Primeiro índice de leitura

while(1)                       % Espera para ler a mensagem inicial
    tmp = srl_read(s1, 1);     % Lê um byte
    if (isempty(tmp))          % Verifica se leu algo
        break;
    endif
    t(i) = tmp;                % Armazena o byte
    if (t(i) == 10)            % Se for lido um enter (10 em ASCII)
        break;                 % Sai do loop
    endif
    i = i + 1;                 % Incrementa o índice de leitura
end

t = t(1:i);                    % Ajusta o tamanho final do array
c = char(t);                   % Transformando caracteres recebidos em string
printf('recebido: %s', c);     % Imprime na tela do octave o que foi recebido

%%%%%%%%%%%%%%%%%%% CRIAÇÃO DA FIGURA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure(1);                     % Cria uma figura para plotagem
h1 = subplot(3,1,1);           % Cria o primeiro subplot e guarda o handle
h2 = subplot(3,1,2);           % Cria o segundo subplot e guarda o handle
h3 = subplot(3,1,3);           % Cria o terceiro subplot e guarda o handle

%%%%%%%%%%%%%%%%%%% LOOP PRINCIPAL COM ATUALIZAÇÃO A CADA SEGUNDO %%%%%%%%%%%%%
try
    while (1)                   % Loop infinito (até Ctrl+C)
        tic;                    % Inicia contador de tempo

        % Limpa dados anteriores
        data = [];

        % Lê dados disponíveis (até 'amostras' ou até timeout)
        for i = 1:amostras
            % Lê uma linha completa (até encontrar o caractere de nova linha)
            line = '';
            byte = 0;
            try
                % Lê até encontrar nova linha ou timeout
                timeout_count = 0;
                while (byte != 10 && timeout_count < 100)  % ASCII 10 = nova linha
                    tmp = srl_read(s1, 1);
                    if (isempty(tmp))
                        timeout_count++;
                        pause(0.01);     % Pequena pausa para dar tempo ao Arduino
                        continue;
                    endif
                    byte = tmp;
                    if (byte != 10)
                        line = [line, char(byte)];
                    endif
                end

                % Converte a string para número e adiciona ao array de dados
                if (length(line) > 0)
                    num_val = str2num(line);
                    if (!isempty(num_val))
                        data(end+1) = num_val;
                    endif
                endif
            catch
                % Continua se houver erro
                continue;
            end

            % Verifica se já temos amostras suficientes
            ##if (length(data) >= amostras)
              ##  break;
            ##endif
        end

        % Se recebeu dados, atualiza os gráficos
        if (length(data) > 0)
            raw = data;                  % Armazena os dados brutos
            time = (0:length(raw)-1)/fs; % Vetor de tempo normalizado (em segundos)

            str = '[';
            for i = 1:length(data)
                str = [str, num2str(data(i))];
                if i < length(data)
                    str = [str, ', '];
                endif
            endfor
            str = [str, ']'];
            printf('%s\n\n\n\n\n\n\n\n\n', str);


            % Atualiza o primeiro subplot
            subplot(h1);
            plot(time, raw*5/1023);      % Converte os valores ADC para tensão (0-5V)
            xlabel('t(s)');
            ylabel('Tensão (V)');
            title('Sinal gerado x(t)');
            grid on;

            % Atualiza o segundo subplot
            subplot(h2);
            stem(raw,'.');                   % Plota amostras discretas
            xlabel('n');
            ylabel('Valor ADC');
            title('x[n]');
            grid on;

            % Atualiza o terceiro subplot
            subplot(h3);
            stairs(raw);                 % Plota amostras regulares em forma de escada
            xlabel('n');
            ylabel('Valor ADC');
            title('x[n] segurado');
            grid on;

            % Força atualização da figura
            drawnow;
        else
            printf("Nenhum dado recebido nesta iteração\n");
        end

        % Calcula tempo restante para completar 1 segundo
        elapsed = toc;
        if (elapsed < 1)
            pause(1 - elapsed);  % Pausa para completar 1 segundo
        end

        % Exibe a taxa de amostragem atual
        printf('Amostras coletadas: %d, Tempo: %.2f s\n', length(data), elapsed);
    end
catch err
    % Captura exceções (como Ctrl+C)
    printf('Programa interrompido: %s\n', err.message);
end

%%%%%%%%%%%%%%%%%%% FECHA A PORTA DE COMUNICAÇÃO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fclose(s1);
printf('Porta serial fechada.\n');
