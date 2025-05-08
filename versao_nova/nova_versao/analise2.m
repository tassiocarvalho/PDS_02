clc;                           %limpa a tela do octave
clear all;                     %limpa todas as variáveis do octave
close all;                     %fecha todas as janelas

%%%%%%%%%%%%%%%%%%% CHAMADA DAS BIBLIOTECAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pkg load signal                %biblioteca para processamento de sinais
pkg load instrument-control    %biblioteca para comunicação serial

%%%%%%%%%%%%%%%%%%% ALOCAÇÃO DE VARIÁVEIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
MAX_RESULTS = 2048;            % Mesmo valor definido no Arduino
fs = 10230;                    % Frequência de amostragem do ADC no Arduino (para 2046 amostras a 5Hz)
amostras = 2048                % Quantidade de amostras para visualizar
raw = [];                      % Variável para armazenar os dados recebidos pela USB

%%%%%%%%%%%%%%%%%%% PARÂMETROS DO SINAL E ADC %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
N_bits = 10;                   % Resolução do ADC em bits
V_ref = 5.0;                   % Tensão de referência do ADC (0-5V)
num_codes = 2^N_bits;          % Número total de códigos ADC (1024)
LSB_volts = V_ref / num_codes; % Valor de 1 LSB em volts
f_input = 5.0;                 % Frequência do sinal triangular (5Hz)
periodo = 1/f_input;           % Período do sinal (0.2s)
samples_per_cycle = 2046;      % 1023 amostras na subida + 1023 na descida
ideal_fs = f_input * samples_per_cycle; % Taxa de amostragem ideal (~10230Hz)

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

%%%%%%%%%%%%%%%%%%% CRIAÇÃO DAS FIGURAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Figura 1: Visualização do sinal
figure(1);
h1 = subplot(3,1,1);           % Cria o primeiro subplot e guarda o handle
h2 = subplot(3,1,2);           % Cria o segundo subplot e guarda o handle
h3 = subplot(3,1,3);           % Cria o terceiro subplot e guarda o handle

% Figura 2: Análise de erros (criada quando necessário)

% Variável para controlar a frequência da análise de erros
contador_analise = 0;

% Armazena o último conjunto completo de dados para análise
ultimo_conjunto_completo = [];

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

            % Se recebemos um conjunto completo de dados, armazena para análise posterior
            if (length(raw) >= samples_per_cycle)
                ultimo_conjunto_completo = raw;
            endif

            % Atualiza o primeiro subplot - sinal no domínio do tempo (Volts)
            subplot(h1);
            plot(time, raw*V_ref/(num_codes-1));  % Converte para tensão
            xlabel('Tempo (s)');
            ylabel('Tensão (V)');
            title('Sinal Analógico Reconstruído x(t)');
            grid on;
            ylim([0 V_ref]);  % Limita o eixo Y de 0 a 5V

            % Atualiza o segundo subplot - amostras discretas (código ADC)
            subplot(h2);
            stem(raw,'.');
            xlabel('Índice da Amostra (n)');
            ylabel('Valor ADC');
            title('Amostras Discretas x[n]');
            grid on;
            ylim([0 num_codes-1]);  % Limita o eixo Y de 0 a 1023

            % Atualiza o terceiro subplot - amostra-e-segura (código ADC)
            subplot(h3);
            stairs(raw);
            xlabel('Índice da Amostra (n)');
            ylabel('Valor ADC');
            title('Sample-and-Hold x[n]');
            grid on;
            ylim([0 num_codes-1]);  % Limita o eixo Y de 0 a 1023

            % Força atualização da figura
            drawnow;

            % Incrementa contador de análise e verifica se é hora de fazer análise de erros
            contador_analise++;
            if (contador_analise >= 5 && !isempty(ultimo_conjunto_completo) && length(ultimo_conjunto_completo) >= samples_per_cycle/2)
                contador_analise = 0;  % Reinicia o contador

                %%%%%%%%%%%%%%%%%%% ANÁLISE DE ERROS ADC %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                printf("\n===== ANÁLISE DE ERROS ADC - SINAL TRIANGULAR 5Hz =====\n");

                % Usar o conjunto completo armazenado para análise
                raw_analysis = ultimo_conjunto_completo;

                % 1. Verificação de repetições consecutivas
                repeticoes = 0;
                valores_repetidos = [];
                for j = 1:length(raw_analysis)-1
                    if raw_analysis(j) == raw_analysis(j+1)
                        repeticoes++;
                        valores_repetidos(end+1) = raw_analysis(j);
                    endif
                endfor

                % Remove duplicatas dos valores repetidos
                valores_repetidos = unique(valores_repetidos);

                % 2. Contagem de códigos para histograma
                codigo_counts = zeros(1, num_codes);
                for j = 0:num_codes-1
                    codigo_counts(j+1) = sum(raw_analysis == j);
                endfor

                % 3. Análise da faixa dinâmica
                min_valor = min(raw_analysis);
                max_valor = max(raw_analysis);
                faixa_dinamica = max_valor - min_valor;

                % 4. Gerar sinal triangular ideal para comparação
                % Para um ciclo completo do sinal triangular de 5Hz
                ciclo_pontos = length(raw_analysis);
                t_ideal = (0:ciclo_pontos-1)/fs;
                t_mod = mod(t_ideal * f_input, 1);  % Posição normalizada no ciclo (0-1)

                % Gera forma triangular entre 0 e 1
                triangular_norm = zeros(size(t_mod));
                for j = 1:length(t_mod)
                    if t_mod(j) < 0.5
                        triangular_norm(j) = 2 * t_mod(j);  % Subida (0 a 1)
                    else
                        triangular_norm(j) = 2 * (1 - t_mod(j));  % Descida (1 a 0)
                    endif
                endfor

                % Escala para a faixa do ADC
                ideal_signal = round(triangular_norm * (num_codes-1));

                % 5. Códigos ausentes (missing codes)
                codigos_ausentes = [];
                faixa_analise = max_valor - min_valor + 1;

                for j = min_valor:max_valor
                    if codigo_counts(j+1) == 0
                        codigos_ausentes(end+1) = j;
                    endif
                endfor

                % 6. Cálculo de erro absoluto entre sinal real e ideal
                erro_absoluto = raw_analysis - ideal_signal;
                max_erro_abs = max(abs(erro_absoluto));
                min_erro_abs = min(abs(erro_absoluto));
                media_erro_abs = mean(abs(erro_absoluto));

                % 7. Erro de offset (distância do mínimo até zero)
                offset_error = min_valor - 0;
                offset_error_v = offset_error * LSB_volts;

                % 8. Cálculo de DNL (Differential Non-Linearity)
                % Para um sinal triangular, a contagem de cada código deve ser aproximadamente igual
                contagens_codigos_presentes = codigo_counts(min_valor+1:max_valor+1);
                contagens_codigos_presentes = contagens_codigos_presentes(contagens_codigos_presentes > 0);
                contagem_media = mean(contagens_codigos_presentes);

                dnl = zeros(1, num_codes);
                for j = min_valor:max_valor
                    if contagem_media > 0
                        dnl(j+1) = (codigo_counts(j+1) / contagem_media) - 1;
                    endif
                endfor

                % 9. Cálculo de INL (Integral Non-Linearity)
                inl = zeros(1, num_codes);
                % Cálculo simples: soma cumulativa do DNL
                inl(min_valor+1:max_valor+1) = cumsum(dnl(min_valor+1:max_valor+1));

                % 10. Efeito da ausência de bits específicos
                % Simulação de perda do bit menos significativo (LSB)
                raw_no_lsb = bitand(raw_analysis, 1022);  % Remove o LSB (bit 0)
                lsb_error = raw_analysis - raw_no_lsb;
                max_lsb_error = max(abs(lsb_error));
                avg_lsb_error = mean(abs(lsb_error));

                % Exibição dos resultados no terminal
                printf("• Parâmetros de Aquisição:\n");
                printf("  Resolução: %d bits (%d níveis)\n", N_bits, num_codes);
                printf("  Frequência do sinal: %.1f Hz\n", f_input);
                printf("  Taxa de amostragem: %.0f Hz\n", fs);
                printf("  Amostras por ciclo: %d (ideal: %d)\n", length(raw_analysis), samples_per_cycle);
                printf("  1 LSB = %.4f V\n", LSB_volts);

                printf("\n• Análise da Faixa Dinâmica:\n");
                printf("  Código mínimo: %d (%.3f V)\n", min_valor, min_valor*LSB_volts);
                printf("  Código máximo: %d (%.3f V)\n", max_valor, max_valor*LSB_volts);
                printf("  Faixa dinâmica: %d códigos (%.3f V)\n", faixa_dinamica, faixa_dinamica*LSB_volts);

                printf("\n• Análise de Repetições:\n");
                printf("  Total de repetições consecutivas: %d\n", repeticoes);
                if !isempty(valores_repetidos) && length(valores_repetidos) <= 15
                    printf("  Códigos com repetições: %s\n", mat2str(valores_repetidos));
                elseif !isempty(valores_repetidos)
                    printf("  %d códigos diferentes apresentaram repetições consecutivas\n", length(valores_repetidos));
                endif

                printf("\n• Análise de Códigos Ausentes:\n");
                if !isempty(codigos_ausentes)
                    percent_ausentes = 100 * length(codigos_ausentes) / faixa_analise;
                    printf("  %d códigos ausentes na faixa %d-%d (%.1f%%)\n",
                           length(codigos_ausentes), min_valor, max_valor, percent_ausentes);
                    if length(codigos_ausentes) <= 15
                        printf("  Códigos ausentes: %s\n", mat2str(codigos_ausentes));
                    endif
                else
                    printf("  Nenhum código ausente na faixa observada %d-%d\n", min_valor, max_valor);
                endif

                printf("\n• Erros de Conversão:\n");
                printf("  Erro de offset: %d códigos (%.3f V)\n", offset_error, offset_error_v);
                printf("  Erro absoluto máximo: %.2f LSB\n", max_erro_abs);
                printf("  Erro absoluto médio: %.2f LSB\n", media_erro_abs);

                printf("\n• Análise de Não-Linearidade:\n");
                printf("  DNL máximo: %.3f LSB\n", max(dnl(min_valor+1:max_valor+1)));
                printf("  DNL mínimo: %.3f LSB\n", min(dnl(min_valor+1:max_valor+1)));
                printf("  INL máximo: %.3f LSB\n", max(inl(min_valor+1:max_valor+1)));
                printf("  INL mínimo: %.3f LSB\n", min(inl(min_valor+1:max_valor+1)));

                printf("\n• Simulação de Ausência de Bits:\n");
                printf("  Erro por ausência do LSB: Máx = %.2f LSB, Média = %.2f LSB\n",
                       max_lsb_error, avg_lsb_error);

                % Figura com análises
                figure(2);

                % Histograma
                subplot(2,2,1);
                bar(min_valor:max_valor, codigo_counts(min_valor+1:max_valor+1));
                title('Histograma de Códigos ADC');
                xlabel('Código ADC');
                ylabel('Contagem');
                grid on;

                % DNL
                subplot(2,2,2);
                bar(min_valor:max_valor, dnl(min_valor+1:max_valor+1));
                title('Erro de Não-Linearidade Diferencial (DNL)');
                xlabel('Código ADC');
                ylabel('DNL (LSB)');
                grid on;
                ylim([-2, 2]);  % Limita para melhor visualização

                % INL
                subplot(2,2,3);
                bar(min_valor:max_valor, inl(min_valor+1:max_valor+1));
                title('Erro de Não-Linearidade Integral (INL)');
                xlabel('Código ADC');
                ylabel('INL (LSB)');
                grid on;
                ylim([-5, 5]);  % Limita para melhor visualização

                % Erro absoluto
                subplot(2,2,4);
                plot(erro_absoluto);
                title('Erro Absoluto (Real - Ideal)');
                xlabel('Índice da Amostra');
                ylabel('Erro (LSB)');
                grid on;

                drawnow;

                printf("===== FIM DA ANÁLISE =====\n\n");
            endif

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
