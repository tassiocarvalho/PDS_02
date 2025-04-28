clc;                           %limpa a tela do octave
clear all;                     %limpa todas as variáveis do octave
close all;                     %fecha todas as janelas

%%%%%%%%%%%%%%%%%%% CHAMADA DAS BIBLIOTECAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pkg load signal                %biblioteca para processamento de sinais
pkg load instrument-control    %biblioteca para comunicação serial

%%%%%%%%%%%%%%%%%%% FUNÇÕES AUXILIARES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Função para estimar parâmetros do sinal
function [amplitude, frequencia, offset] = estimateSignalParams(dados, fs)
    % Estima amplitude, frequência e offset de um sinal (função genérica)

    % Amplitude
    amplitude = max(dados) - min(dados);

    % Offset (valor médio)
    offset = mean(dados);

    % Frequência - usando FFT
    N = length(dados);
    Y = fft(dados);
    Y = abs(Y(1:floor(N/2)+1));
    Y(1) = 0; % Remove componente DC
    [~, idx] = max(Y);

    % Calcula frequência
    f = (0:floor(N/2))*fs/N;
    frequencia = f(idx);
endfunction

% Função para gerar sinal triangular ideal
function sinal = generateTriangularSignal(frequencia, amplitude, offset, num_amostras, fs)
    % Gera um sinal triangular com a frequência, amplitude e offset especificados

    t = (0:num_amostras-1)/fs;
    periodo = 1/frequencia;

    % Normaliza o tempo para o intervalo [0, 1] dentro de cada período
    fase = mod(t, periodo)/periodo;

    % Gera forma triangular
    sinal = zeros(size(fase));

    % Divide o sinal em regiões de subida e descida
    for i = 1:length(fase)
        if fase(i) < 0.5
            % Região de subida (0 a 0.5 do período)
            sinal(i) = fase(i) * 2;
        else
            % Região de descida (0.5 a 1 do período)
            sinal(i) = 2 - fase(i) * 2;
        end
    end

    % Ajusta para a amplitude e offset desejados
    sinal = offset + amplitude * (sinal - 0.5);
endfunction

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
h1 = subplot(4,1,1);           % Cria o primeiro subplot e guarda o handle
h2 = subplot(4,1,2);           % Cria o segundo subplot e guarda o handle
h3 = subplot(4,1,3);           % Cria o terceiro subplot e guarda o handle
h4 = subplot(4,1,4);           % Cria o quarto subplot para comparação

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
            time = (0:length(raw)-1)/fs; % Vetor de tempo normalizado (em segundos)

            % Atualiza o primeiro subplot
            subplot(h1);
            plot(time, raw*5/1023);      % Converte os valores ADC para tensão (0-5V)
            xlabel('t(s)');
            ylabel('Tensão (V)');
            title('Sinal gerado x(t)');
            grid on;

            % Atualiza o segundo subplot
            subplot(h2);
            stem(raw);                   % Plota amostras discretas
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

            % Análise de erros do ADC para sinal triangular
            % Cálculo do valor esperado (assumindo sinal triangular)
            % Para um ADC de 10 bits, o valor máximo é 1023
            max_adc = 1023;

            % Cálculo da tensão real
            tensao_real = raw*5/max_adc;

            % Estimativa do sinal ideal (sinal triangular)
            [amplitude, freq_est, offset] = estimateSignalParams(raw, fs);

            % Gera sinal triangular ideal com os parâmetros estimados
            sinal_ideal = generateTriangularSignal(freq_est, amplitude, offset, length(raw), fs);

            % Adiciona gráfico de comparação entre sinal real e ideal
            subplot(h4);
            hold on;
            plot(raw, 'b', 'LineWidth', 1);
            plot(sinal_ideal, 'r--', 'LineWidth', 1);
            hold off;
            xlabel('n');
            ylabel('Valor ADC');
            title('Comparação: Sinal Real (azul) vs Ideal (vermelho)');
            legend('Sinal Real', 'Sinal Ideal');
            grid on;

            % Força atualização da figura
            drawnow;

            % Calcula diferentes tipos de erros
            erro = raw - sinal_ideal;

            % Erro de offset (média do erro)
            erro_offset = mean(erro);

            % Erro de não linearidade integral (INL)
            % Maior desvio do valor real em relação ao ideal
            inl = max(abs(erro));

            % Erro de não linearidade diferencial (DNL)
            % Variação entre degraus consecutivos
            degraus = diff(sort(raw));
            degrau_ideal = 1; % Idealmente cada aumento de 1 no ADC corresponde a um degrau
            dnl = max(abs(degraus - degrau_ideal));

            % Análise de código perdido
            % Em teoria, os bits devem ser distribuídos uniformemente
            % Histograma para verificar distribuição
            [counts, bins] = hist(raw, 50);

            % Verificação de ausência de bits
            % Conta os valores únicos (deve ter próximo a 1024 valores para 10 bits)
            valores_unicos = length(unique(raw));
            bits_ausentes = 10 - log2(valores_unicos);
            if (bits_ausentes < 0)
                bits_ausentes = 0;
            endif

            % Exibe resultados no terminal
            printf('\n---- ANÁLISE DE ERROS DO ADC ----\n');
            printf('Erro de offset: %.2f LSB\n', erro_offset);
            printf('Erro de não linearidade integral (INL): %.2f LSB\n', inl);
            printf('Erro de não linearidade diferencial (DNL): %.2f LSB\n', dnl);
            printf('Bits ausentes estimados: %.1f\n', bits_ausentes);
            printf('Valores únicos detectados: %d de 1024 possíveis\n', valores_unicos);

            % Identifica bits específicos ausentes (análise mais detalhada)
            if valores_unicos < 1024
                % Cria vetor de todos os valores possíveis (0-1023)
                todos_valores = 0:1023;
                % Identifica quais valores não aparecem nos dados
                valores_ausentes = setdiff(todos_valores, unique(raw));
                % Mostra alguns valores ausentes (se não forem muitos)
                if length(valores_ausentes) <= 20
                    printf('Valores específicos ausentes: ');
                    printf('%d ', valores_ausentes);
                    printf('\n');
                else
                    printf('Muitos valores ausentes (%d). Mostrando os primeiros 10: ', length(valores_ausentes));
                    printf('%d ', valores_ausentes(1:10));
                    printf('\n');
                endif

                % Análise de bits específicos ausentes
                bits_problematicos = zeros(1, 10);
                for i = 1:length(valores_ausentes)
                    valor_bin = dec2bin(valores_ausentes(i), 10); % Converte para binário (10 bits)
                    for bit = 1:10
                        if valor_bin(bit) == '1'
                            bits_problematicos(bit) = bits_problematicos(bit) + 1;
                        endif
                    end
                end

                % Identifica bits com maior probabilidade de falha
                [~, idx] = sort(bits_problematicos, 'descend');
                printf('Bits mais problemáticos (do MSB para o LSB): ');
                for i = 1:min(3, length(idx))
                    if bits_problematicos(idx(i)) > 0
                        printf('Bit %d (%.1f%% dos valores ausentes), ', 10-idx(i)+1, 100*bits_problematicos(idx(i))/length(valores_ausentes));
                    endif
                end
                printf('\n');
            endif
            printf('--------------------------------\n\n');
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
