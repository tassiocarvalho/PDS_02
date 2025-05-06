
clc;                           %limpa a tela do octave
clear all;                     %limpa todas as variáveis do octave
close all;                     %fecha todas as janelas

%%%%%%%%%%%%%%%%%%% CHAMADA DAS BIBLIOTECAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pkg load signal                %biblioteca para processamento de sinais
pkg load instrument-control    %biblioteca para comunicação serial

%%%%%%%%%%%%%%%%%%% ALOCAÇÃO DE VARIÁVEIS E PARÂMETROS ADC %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
MAX_RESULTS = 2048;            % Mesmo valor definido no Arduino
fs = 10230;                    % Frequência de amostragem do ADC no Arduino
amostras = 2048                % Quantidade de amostras para visualizar
raw = [];                      % Variável para armazenar os dados recebidos pela USB

N_bits = 10;                   % Resolução do ADC em bits
V_ref = 5.0;                   % Tensão de referência do ADC (0-5V)
num_codes = 2^N_bits;          % Número total de códigos ADC (1024)
LSB_ideal_V = V_ref / num_codes; % Tamanho ideal do LSB em Volts

%%%%%%%%%%%%%%%%%%% ABERTURA DA PORTA SERIAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ATENÇÃO: Altere "COM5" para a porta serial correta do seu sistema (ex: '/dev/ttyUSB0' no Linux)
s_port_name = "COM5";
try
    s1 = serial(s_port_name);
    set(s1, 'baudrate', 115200);   % Mesma velocidade configurada no Arduino (115200)
    set(s1, 'bytesize', 8);        % 8 bits de dados
    set(s1, 'parity', 'n');        % Sem paridade ('y' 'n')
    set(s1, 'stopbits', 1);        % 1 bit de parada (1 ou 2)
    set(s1, 'timeout', 2);         % Tempo ocioso aumentado para 2 segundos para leitura de blocos
    srl_flush(s1);                 % Limpa buffer serial
    printf("Porta serial %s aberta com sucesso.\n", s_port_name);
    pause(1);                      % Espera 1 segundo antes de ler dados
catch err
    printf("Erro ao abrir a porta serial %s: %s\n", s_port_name, err.message);
    printf("Verifique se a porta está correta e disponível, e se o pacote instrument-control está carregado.\n");
    return;
end

%%%%%%%%%%%%%%%%%%% LEITURA DA MENSAGEM INICIAL (OPCIONAL) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Este bloco pode ler os primeiros dados ou uma mensagem de saudação do Arduino
t_init_msg = zeros(1, 100);      % Pré-aloca com tamanho suficiente
i_init_msg = 1;                  % Primeiro índice de leitura

printf("Tentando ler mensagem inicial da serial...\n");
msg_timeout_count = 0;
while(msg_timeout_count < 5) % Tenta ler por um curto período
    tmp_byte = srl_read(s1, 1);     % Lê um byte
    if (isempty(tmp_byte))
        msg_timeout_count++;
        pause(0.1);
        continue;
    endif
    t_init_msg(i_init_msg) = tmp_byte; % Armazena o byte
    if (t_init_msg(i_init_msg) == 10)  % Se for lido um enter (10 em ASCII)
        break;                 % Sai do loop
    endif
    if (i_init_msg >= length(t_init_msg))
        break; % Evita estouro do buffer pré-alocado
    endif
    i_init_msg = i_init_msg + 1;       % Incrementa o índice de leitura
end

if (i_init_msg > 1)
    t_init_msg = t_init_msg(1:i_init_msg-1); % Ajusta o tamanho final do array (remove possível LF final se não for parte da msg)
    c_init_msg = char(t_init_msg);
    printf("Recebido inicialmente: %s\n", c_init_msg);
else
    printf("Nenhuma mensagem inicial significativa recebida.\n");
end
srl_flush(s1); % Limpa novamente para garantir que começaremos a ler os dados numéricos

%%%%%%%%%%%%%%%%%%% CRIAÇÃO DAS FIGURAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Figura para sinal no tempo e valores ADC
figure(1);
clf; % Limpa a figura
h_signal_time = subplot(3,1,1);
h_signal_adc_stem = subplot(3,1,2);
h_signal_adc_stairs = subplot(3,1,3);

% Figura para análise de erros ADC
figure(2);
clf; % Limpa a figura
h_hist = subplot(3,1,1);
h_dnl = subplot(3,1,2);
h_inl = subplot(3,1,3);

%%%%%%%%%%%%%%%%%%% LOOP PRINCIPAL COM ATUALIZAÇÃO %%%%%%%%%%%%%
printf("Iniciando loop principal de aquisição e análise... (Pressione Ctrl+C para parar)\n");
try
    while (1)                   % Loop infinito (até Ctrl+C)
        tic;                    % Inicia contador de tempo

        % Limpa dados anteriores para a iteração atual
        data_buffer = [];

        % Lê dados disponíveis (até 'amostras' ou até timeout)
        % O Arduino envia MAX_RESULTS (2048) amostras por vez
        printf("Aguardando %d amostras do Arduino...\n", amostras);
        for k_sample = 1:amostras
            line_str = '';
            current_byte = 0;
            read_timeout_count = 0;

            % Lê uma linha completa (até encontrar o caractere de nova linha)
            while (current_byte != 10 && read_timeout_count < 200)  % ASCII 10 = nova linha, timeout aumentado
                byte_read = srl_read(s1, 1);
                if (isempty(byte_read))
                    read_timeout_count++;
                    pause(0.005); % Pequena pausa para não sobrecarregar CPU e dar tempo ao Arduino
                    continue;
                endif
                current_byte = byte_read;
                if (current_byte != 10 && current_byte != 13) % Ignora CR (13) se presente
                    line_str = [line_str, char(current_byte)];
                endif
            end

            if (read_timeout_count >= 200)
                %printf("Timeout ao ler linha %d.\n", k_sample);
                %break; % Sai do loop de leitura de amostras se houver timeout persistente
            endif

            % Converte a string para número e adiciona ao array de dados
            if (length(line_str) > 0)
                num_val = str2double(line_str); % Usar str2double para melhor conversão
                if (!isempty(num_val) && isfinite(num_val))
                    data_buffer(end+1) = num_val;
                else
                    %printf("Valor inválido ou não numérico recebido: '%s'\n", line_str);
                endif
            endif

            % Se já lemos menos amostras que o esperado e o timeout da porta ocorreu,
            % pode ser o fim de um bloco de dados do Arduino.
            if (srl_stat(s1) == 0 && k_sample < amostras && length(line_str)==0)
                 %printf("Buffer serial aparentemente vazio antes de completar %d amostras.\n", amostras);
                 %break;
            endif
        end % Fim do loop de leitura de amostras

        printf("Recebidas %d amostras nesta iteração.\n", length(data_buffer));

        % Se recebeu dados suficientes, atualiza os gráficos e faz análise de erros
        if (length(data_buffer) > (num_codes / 4)) % Processa se tiver um número razoável de amostras
            raw = data_buffer(:); % Garante que é um vetor coluna

            % --- Plotagens do Sinal (Figura 1) ---
            time_vec = (0:length(raw)-1)/fs; % Vetor de tempo normalizado (em segundos)

            subplot(h_signal_time);
            plot(time_vec, raw * LSB_ideal_V); % Converte os valores ADC para tensão
            xlabel('Tempo (s)');
            ylabel('Tensão (V)');
            title(['Sinal Adquirido x(t) - ' num2str(length(raw)) ' amostras']);
            grid on;
            axis tight;

            subplot(h_signal_adc_stem);
            stem(raw,'.');
            xlabel('Índice da Amostra (n)');
            ylabel('Valor ADC (0-1023)');
            title('Amostras ADC x[n]');
            grid on;
            axis tight;
            ylim([0 num_codes-1]);

            subplot(h_signal_adc_stairs);
            stairs(raw);
            xlabel('Índice da Amostra (n)');
            ylabel('Valor ADC (0-1023)');
            title('Amostras ADC x[n] (Segurador Ordem Zero)');
            grid on;
            axis tight;
            ylim([0 num_codes-1]);

            drawnow; % Atualiza Figura 1

            % --- Análise de Erros ADC (Figura 2) ---
            printf("\n--- Iniciando Análise de Erros ADC ---\n");
            codes_adc = 0:(num_codes-1);

            % 1. Histograma dos códigos ADC
            adc_histogram = histc(raw, codes_adc);
            subplot(h_hist);
            bar(codes_adc, adc_histogram);
            title('Histograma dos Códigos ADC');
            xlabel('Código ADC');
            ylabel('Contagens');
            grid on;
            xlim([-0.5 num_codes-0.5]);

            % 2. Erro de Offset (simplificado)
            % Idealmente, o primeiro código (0) ou o último (1023) devem ser atingidos.
            % Offset pode ser visto como o desvio do código mínimo/máximo esperado.
            % Para um sinal 0-5V, o código 0 deve ser atingido.
            min_code_observed = min(raw);
            max_code_observed = max(raw);
            offset_error_lsb = min_code_observed - 0; % Assumindo que 0 é o código esperado para 0V
            printf("Erro de Offset (código mínimo observado - 0): %.2f LSB\n", offset_error_lsb);
            printf("Código Mínimo Observado: %d, Código Máximo Observado: %d\n", min_code_observed, max_code_observed);

            % 3. Ausência de Bits (Códigos Faltantes)
            % Verifica códigos entre min_code_observed e max_code_observed que não foram atingidos
            % Consideramos códigos faltantes aqueles com 0 hits no histograma, excluindo os extremos não atingidos.
            relevant_codes_for_missing = min_code_observed:max_code_observed;
            if (length(relevant_codes_for_missing) > 1)
                histogram_relevant = adc_histogram(relevant_codes_for_missing + 1); % +1 para indexar histograma
                missing_codes_indices = relevant_codes_for_missing(histogram_relevant == 0);
                num_missing_codes = length(missing_codes_indices);
                printf("Número de Códigos Faltantes (entre %d e %d): %d\n", min_code_observed, max_code_observed, num_missing_codes);
                if num_missing_codes > 0 && num_missing_codes < 20 % Lista se poucos
                    printf("Códigos faltantes: %s\n", num2str(missing_codes_indices));
                endif
            else
                printf("Não há dados suficientes para análise de códigos faltantes robusta.\n");
                num_missing_codes = -1; % Indica não calculado
            endif

            % 4. DNL (Erro de Não Linearidade Diferencial) - Método do Histograma
            % Válido se o sinal de entrada varre uniformemente a faixa do ADC (ex: rampa, triangular)
            % DNL(i) = (H(i) / H_ideal) - 1 [LSB]
            % H(i) é a contagem para o código i. H_ideal é a contagem média esperada por código.

            % Considerar apenas códigos que foram atingidos pelo menos uma vez para H_ideal robusto
            active_codes_mask = adc_histogram > 0;
            num_active_codes = sum(active_codes_mask);
            total_hits_active_range = sum(adc_histogram(active_codes_mask));

            DNL = zeros(1, num_codes);
            if num_active_codes > 1 % Precisa de pelo menos 2 códigos ativos
                avg_hits_per_active_code = total_hits_active_range / num_active_codes;
                % Para DNL, geralmente se exclui o primeiro e último código da faixa total
                % ou se calcula sobre os códigos efetivamente varridos.
                % Vamos calcular para todos os códigos, mas plotar/reportar para a faixa relevante.
                for i_code = 1:num_codes
                    if avg_hits_per_active_code > 1e-6 % Evita divisão por zero se nenhum hit
                        DNL(i_code) = (adc_histogram(i_code) / avg_hits_per_active_code) - 1;
                    else
                        DNL(i_code) = 0; % Ou NaN
                    endif
                end
                % DNL não é bem definido para códigos com zero hits se avg_hits_per_active_code é baseado em códigos ativos.
                % Alternativa: H_ideal = total_samples / num_codes_total_range (se toda a faixa é varrida)
                avg_hits_ideal_full_range = length(raw) / (max_code_observed - min_code_observed + 1);
                if (max_code_observed - min_code_observed +1) > 1
                    for i_code = min_code_observed:max_code_observed
                         DNL(i_code+1) = (adc_histogram(i_code+1) / avg_hits_ideal_full_range) -1;
                    endfor
                endif

                % Plot DNL (para códigos observados)
                codes_to_plot_dnl = min_code_observed:max_code_observed;
                if length(codes_to_plot_dnl) > 1
                    subplot(h_dnl);
                    plot(codes_to_plot_dnl, DNL(codes_to_plot_dnl+1));
                    title('DNL (Erro Diferencial)');
                    xlabel('Código ADC');
                    ylabel('DNL (LSB)');
                    grid on;
                    max_abs_dnl = max(abs(DNL(codes_to_plot_dnl+1)));
                    ylim([-max(2,max_abs_dnl*1.1) max(2,max_abs_dnl*1.1)]); % Ajusta Y-axis
                    printf("DNL Máximo (na faixa observada %d-%d): %.3f LSB\n", min_code_observed, max_code_observed, max(DNL(codes_to_plot_dnl+1)));
                    printf("DNL Mínimo (na faixa observada %d-%d): %.3f LSB\n", min_code_observed, max_code_observed, min(DNL(codes_to_plot_dnl+1)));
                else
                    subplot(h_dnl); cla; title('DNL (Dados insuficientes)');
                    printf("DNL: Dados insuficientes para plotagem/cálculo robusto.\n");
                endif
            else
                subplot(h_dnl); cla; title('DNL (Dados insuficientes)');
                printf("DNL: Dados insuficientes para cálculo (menos de 2 códigos ativos).\n");
            endif

            % 5. INL (Erro de Não Linearidade Integral)
            % INL(k) = sum(DNL(i)) for i=0 to k (ou sobre a faixa relevante)
            INL = zeros(1, num_codes);
            if num_active_codes > 1 && length(codes_to_plot_dnl) > 1
                % INL é a soma cumulativa do DNL.
                % INL é geralmente ajustado para que INL(primeiro_codigo) = 0 e INL(ultimo_codigo) = 0
                % Aqui, uma versão mais simples: soma cumulativa direta.
                INL_calc_range = DNL(min_code_observed+1 : max_code_observed+1);
                INL_cumulative = cumsum(INL_calc_range);

                % Endpoint fit: Subtrai uma linha entre o primeiro e último ponto do INL cumulativo
                % para forçar INL(min_code_observed)=0 e INL(max_code_observed)=0.
                x_inl = 1:length(INL_cumulative);
                line_fit_params = polyfit(x_inl([1,end]), INL_cumulative([1,end]), 1);
                best_fit_line = polyval(line_fit_params, x_inl);
                INL_adjusted = INL_cumulative - best_fit_line;

                INL(min_code_observed+1 : max_code_observed+1) = INL_adjusted;

                subplot(h_inl);
                plot(codes_to_plot_dnl, INL_adjusted);
                title('INL (Erro Integral - Ajustado por Endpoints)');
                xlabel('Código ADC');
                ylabel('INL (LSB)');
                grid on;
                max_abs_inl = max(abs(INL_adjusted));
                ylim([-max(2,max_abs_inl*1.1) max(2,max_abs_inl*1.1)]); % Ajusta Y-axis
                printf("INL Máximo (na faixa observada %d-%d, ajustado): %.3f LSB\n", min_code_observed, max_code_observed, max(INL_adjusted));
                printf("INL Mínimo (na faixa observada %d-%d, ajustado): %.3f LSB\n", min_code_observed, max_code_observed, min(INL_adjusted));
            else
                subplot(h_inl); cla; title('INL (Dados insuficientes)');
                printf("INL: Dados insuficientes para cálculo robusto.\n");
            endif

            drawnow; % Atualiza Figura 2
            printf("--- Fim da Análise de Erros ADC ---\n");

        else
            printf("Dados insuficientes para análise completa nesta iteração (%d amostras).\n", length(data_buffer));
            % Limpa plots de erro se não houver dados suficientes
            subplot(h_hist); cla; title('Histograma (Aguardando dados)');
            subplot(h_dnl); cla; title('DNL (Aguardando dados)');
            subplot(h_inl); cla; title('INL (Aguardando dados)');
            drawnow;
        end

        % Calcula tempo restante para completar aproximadamente 1 segundo de ciclo de atualização
        elapsed_time = toc;
        printf("Tempo da iteração: %.2f s\n", elapsed_time);
        if (elapsed_time < 1.5) % Tenta manter um ciclo de ~1.5s se o processamento for rápido
            pause(1.5 - elapsed_time);
        end

    end % Fim do loop while(1)
catch err
    % Captura exceções (como Ctrl+C)
    printf('\nPrograma interrompido pelo usuário ou erro: %s\n', err.message);
    if isfield(err, 'stack') && length(err.stack) > 0
        printf('Erro na linha %d do arquivo %s\n', err.stack(1).line, err.stack(1).name);
    endif
end

%%%%%%%%%%%%%%%%%%% FECHA A PORTA DE COMUNICAÇÃO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
finally % Garante que a porta serial seja fechada mesmo em caso de erro
    if (exist('s1', 'var') && isobject(s1))
        fclose(s1);
        printf('Porta serial %s fechada.\n', s_port_name);
    else
        printf('Variável da porta serial não existe ou não é um objeto.\n');
    endif
end_try_catch

printf("Script finalizado.\n");


