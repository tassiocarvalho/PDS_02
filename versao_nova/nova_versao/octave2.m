clc;                           %limpa a tela do octave
clear all;                     %limpa todas as variáveis do octave
close all;                     %fecha todas as janelas

%%%%%%%%%%%%%%%%%%% CHAMADA DAS BIBLIOTECAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pkg load signal                %biblioteca para processamento de sinais
pkg load instrument-control    %biblioteca para comunicação serial

%%%%%%%%%%%%%%%%%%% ALOCAÇÃO DE VARIÁVEIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
MAX_RESULTS = 3072;            % Mesmo valor definido no Arduino
fs = 10230;                    % Frequência de amostragem do ADC no Arduino
amostras = 3072                  % Quantidade de amostras para visualizar
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
h1 = subplot(3,2,1);           % Cria o primeiro subplot e guarda o handle
h2 = subplot(3,2,2);           % Cria o segundo subplot e guarda o handle
h3 = subplot(3,2,3);           % Cria o terceiro subplot e guarda o handle
h4 = subplot(3,2,4);           % Histograma para ausência de bit
h5 = subplot(3,2,5);           % DNL
h6 = subplot(3,2,6);           % INL

% Vetor para armazenar histórico de dados para análise de erros
data_history = [];

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
            if (length(data) >= amostras)
                break;
            endif
        end

        % Se recebeu dados, atualiza os gráficos
        if (length(data) > 0)
            raw = data;                  % Armazena os dados brutos

            % Acumula dados para melhor análise de erros (mantém até MAX_RESULTS*5)
            data_history = [data_history, raw];
            if (length(data_history) > MAX_RESULTS*5)
                data_history = data_history(end-MAX_RESULTS*5+1:end);
            endif

            time = (0:length(raw)-1)/fs; % Vetor de tempo normalizado (em segundos)

            % Atualiza o primeiro subplot - Sinal Reconstruído
            subplot(h1);
            plot(time, raw*5/1023);      % Converte os valores ADC para tensão (0-5V)
            xlabel('t(s)');
            ylabel('Tensão (V)');
            title('Sinal gerado x(t)');
            grid on;

            % Atualiza o segundo subplot - Amostras Discretas
            subplot(h2);
            stem(raw,'.');                   % Plota amostras discretas
            xlabel('n');
            ylabel('Valor ADC');
            title('x[n]');
            grid on;

            % Atualiza o terceiro subplot - Sinal Escada
            subplot(h3);
            stairs(raw);                 % Plota amostras regulares em forma de escada
            xlabel('n');
            ylabel('Valor ADC');
            title('x[n] segurado');
            grid on;

            %%%%%%%%%%%%%%%%%%% ANÁLISE DE ERROS DO ADC %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Calcular histograma dos códigos para detectar ausência de bit
            subplot(h4);
            [counts, bins] = hist(data_history, 0:1023);  % Um bin para cada código possível
            bar(bins, counts);
            title('Histograma - Detecção de Ausência de Bit');
            xlabel('Código ADC');
            ylabel('Frequência');

            % Encontra e destaca códigos ausentes
            missing_codes = find(counts == 0);
            if (!isempty(missing_codes))
                hold on;
                % Marca códigos ausentes em vermelho
                plot(missing_codes-1, zeros(size(missing_codes)), 'r*', 'MarkerSize', 8);
                hold off;
                % Exibe informação sobre códigos ausentes
                text(0.5, 0.9, sprintf('%d códigos ausentes', length(missing_codes)), ...
                    'Units', 'normalized', 'Color', 'r');
            endif

            % Análise de DNL (Differential Non-Linearity)
            subplot(h5);
            % Normaliza contagens para estimar DNL
            expected_count = mean(counts(counts > 0));  % Média de contagens (excluindo zeros)
            dnl = (counts / expected_count) - 1;  % DNL normalizado

            % Limita DNL para melhor visualização
            dnl(isinf(dnl)) = -1;  % Códigos ausentes
            bar(bins, dnl);
            title('DNL Estimado');
            xlabel('Código ADC');
            ylabel('DNL (LSB)');
            axis([0 1023 -1.2 1.2]);  % Limita visualização
            grid on;

            % Exibe DNL mínimo e máximo
            dnl_min = min(dnl(isfinite(dnl)));
            dnl_max = max(dnl);
            text(0.05, 0.95, sprintf('DNL min: %.2f LSB', dnl_min), ...
                'Units', 'normalized');
            text(0.05, 0.85, sprintf('DNL max: %.2f LSB', dnl_max), ...
                'Units', 'normalized');

            % Análise de INL (Integral Non-Linearity)
            subplot(h6);
            % Calculamos INL como o acúmulo do DNL
            inl = cumsum(dnl);
            % Compensamos pelo offset inicial
            inl = inl - inl(1);

            plot(bins, inl);
            title('INL Estimado');
            xlabel('Código ADC');
            ylabel('INL (LSB)');
            grid on;

            % Exibe INL mínimo e máximo
            inl_min = min(inl);
            inl_max = max(inl);
            text(0.05, 0.95, sprintf('INL min: %.2f LSB', inl_min), ...
                'Units', 'normalized');
            text(0.05, 0.85, sprintf('INL max: %.2f LSB', inl_max), ...
                'Units', 'normalized');

            % Cálculo aproximado do erro de offset
            % Assumindo que o sinal triangular começa em 0V
            adc_min = min(raw);
            offset_error = adc_min;  % Aproximação simples

            % Cálculo aproximado do erro de ganho
            % Assumindo que o sinal triangular atinge 5V
            adc_max = max(raw);
            gain_error = (1023 - adc_max) / 1023 * 100;  % Em porcentagem

            % Exibe erros de offset e ganho
            subplot(h1);
            text(0.05, 0.15, sprintf('Erro de Offset: %d LSB', offset_error), ...
                'Units', 'normalized');
            text(0.05, 0.05, sprintf('Erro de Ganho: %.2f%%', gain_error), ...
                'Units', 'normalized');

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
