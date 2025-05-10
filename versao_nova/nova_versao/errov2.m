clc;
clear all;
close all;

%%%%%%%%%%%%%%%%%%% CHAMADA DAS BIBLIOTECAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pkg load signal
pkg load instrument-control

%%%%%%%%%%%%%%%%%%% ALOCAÇÃO DE VARIÁVEIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
MAX_RESULTS = 3072;
fs = 10230;
amostras = 3072;
raw = [];

countFirstTime = 0;
primeiraAmostraVetorCompleto = [];

isMaior500 = false;
isDescida = false;
isComplet = false;
prevValue = -1;

%%%%%%%%%%%%%%%%%%% GERANDO O VETOR DE REFERÊNCIA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Método mais eficiente em Octave
vetorReferencia = [0:1023, 1022:-1:0];

%%%%%%%%%%%%%%%%%%% ABERTURA DA PORTA SERIAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
s1 = serial("COM5");
set(s1, 'baudrate', 115200);
set(s1, 'bytesize', 8);
set(s1, 'parity', 'n');
set(s1, 'stopbits', 1);
set(s1, 'timeout', 1);
srl_flush(s1);
pause(1);

%%%%%%%%%%%%%%%%%%% LEITURA DA MENSAGEM INICIAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Corrigido: Pré-alocação do array t
t = zeros(1, 100);
i = 1;

% CORREÇÃO: Adicionado um contador de timeout
timeout_count = 0;
max_timeout = 100;  % Máximo de tentativas antes de desistir

% CORREÇÃO: Não esperar pelo preenchimento do vetor primeiraAmostraVetorCompleto
while(i <= 100 && timeout_count < max_timeout)
    tmp = srl_read(s1, 1);
    if (isempty(tmp))
        timeout_count++;
        pause(0.01);  % Pequena pausa
        continue;
    endif
    t(i) = tmp;
    if (t(i) == 10)
        break;
    endif
    i = i + 1;
end

if (i > 1)  % Só ajusta se leu alguma coisa
    t = t(1:i);
    c = char(t);
    printf("Mensagem inicial: %s\n", c);
else
    printf("Timeout ao ler mensagem inicial\n");
end

%%%%%%%%%%%%%%%%%%% LOOP PRINCIPAL COM LIMITE DE TEMPO %%%%%%%%%%%%%
% CORREÇÃO: Definir um limite de tempo ou número de iterações
max_iterations = 10;  % Máximo de iterações para não ficar em loop infinito
iteration_count = 0;

try
    % CORREÇÃO: Mudamos de while(1) para uma condição de saída clara
    while (!isComplet)
        tic;
        printf("Iteração %d: Tentando coletar dados...\n", iteration_count + 1);

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
                        pause(0.01);
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
                        primeiraAmostraVetorCompleto(end+1) = num_val;
                        printf("valor recebido: %d \n", num_val);

                        if (prevValue > num_val)
                          isDescida = true;
                        endif

                        if (num_val > 500)
                          isMaior500 = true;
                        endif

                        if (isDescida && num_val == 0 && isMaior500)
                          isComplet = true;
                          break;
                        endif

                        prevValue = num_val;
                    endif
                endif
            catch
                % Continua se houver erro
                continue;
            end
        end

        % Incrementa o contador de iterações
        iteration_count++;

        % Calcula tempo restante para completar 1 segundo
        elapsed = toc;
        if (elapsed < 1)
            pause(1 - elapsed);
        end

        printf("Iteração %d concluída em %.2f segundos\n", iteration_count, elapsed);
    end

catch err
    % Captura exceções (como Ctrl+C)
    printf('Programa interrompido: %s\n', err.message);
end

% Obter tamanhos dos vetores
tamAmostra = length(primeiraAmostraVetorCompleto);
tamReferencia = length(vetorReferencia);

fprintf('Tamanho do vetor de amostra: %d\n', tamAmostra);
fprintf('Tamanho do vetor de referência: %d\n', tamReferencia);

%%%%%%%%%%%%%%%%%%% MISSING CODE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Código para análise de missing code em Octave com todos os gráficos em uma única figura

% Criar o vetorReferencia conforme especificado
vetorReferencia = [0:1023, 1022:-1:0];

% Assumindo que primeiraAmostraVetorCompleto já foi preenchido em outro lugar
% primeiraAmostraVetorCompleto = []; % Descomente e preencha se necessário

% Para fins de teste, vou criar um exemplo com valores ausentes
% Remova esta parte e use seu vetor real
##primeiraAmostraVetorCompleto = unique([0:2:1023, 1022:-2:0]);

% Encontrar os missing codes (valores presentes em vetorReferencia mas ausentes em primeiraAmostraVetorCompleto)
missingCodes = setdiff(vetorReferencia, primeiraAmostraVetorCompleto);

% Criar um vetor de ocorrência (1 se o código está presente, 0 se está ausente)
ocorrencia = ones(size(vetorReferencia));
for i = 1:length(missingCodes)
    indices = find(vetorReferencia == missingCodes(i));
    ocorrencia(indices) = 0;
end

% Análise dos missing codes
numMissingCodes = length(missingCodes);
percentualMissing = (numMissingCodes / length(unique(vetorReferencia))) * 100;

% Encontrar os índices dos missing codes no vetor de referência
indicesMissing = [];
for i = 1:length(missingCodes)
    indicesMissing = [indicesMissing, find(vetorReferencia == missingCodes(i))];
end

% Gráfico complementar mostrando apenas os missing codes
figure(2);
stem(missingCodes, ones(size(missingCodes)), 'r', 'LineWidth', 1.5);
title(sprintf('Missing Codes: %d valores ausentes (%.2f%%)', numMissingCodes, percentualMissing));
xlabel('Valor');
ylabel('Missing (1)');
xlim([min(vetorReferencia) max(vetorReferencia)]);
grid on;


% Adicionar título principal à figura
##text(0.5, 0.98, sprintf('Análise Completa de Missing Codes - %.2f%% ausentes', percentualMissing), ...
     ##'HorizontalAlignment','center', 'FontSize',14, 'FontWeight','bold');

% Imprimir a análise no console
printf("\n--- Análise de Missing Codes ---\n");
printf("Total de códigos de referência: %d\n", length(vetorReferencia));
printf("Total de códigos de referência únicos: %d\n", length(unique(vetorReferencia)));
printf("Total de códigos na amostra: %d\n", length(primeiraAmostraVetorCompleto));
printf("Número de missing codes únicos: %d\n", numMissingCodes);
printf("Percentual de missing codes: %.2f%%\n", percentualMissing);



%%%%%%%%%%%%%%%%%%% ANÁLISE DE OFFSET %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Cálculo do offset em relação ao sinal de referência

% Criar uma nova figura para análise de offset
figure(3);

% Determinar o offset médio (diferença média entre valores medidos e esperados)
% Primeiro, precisamos alinhar os vetores para comparação correta
tam_min = min(length(primeiraAmostraVetorCompleto), length(vetorReferencia));

% Garantir que temos dados suficientes para análise
if tam_min > 10
    % Recortar os vetores para terem o mesmo tamanho para comparação
    amostra_recortada = primeiraAmostraVetorCompleto(1:tam_min);
    referencia_recortada = vetorReferencia(1:tam_min);

    % Calcular a diferença (offset) ponto a ponto
    diferenca_offset = amostra_recortada - referencia_recortada;

    % Calcular estatísticas do offset
    offset_medio = mean(diferenca_offset);
    offset_std = std(diferenca_offset);
    offset_max = max(diferenca_offset);
    offset_min = min(diferenca_offset);

    % Subplot 1: Comparação direta entre o sinal medido e o de referência
    subplot(3, 1, 1);
    plot(1:tam_min, amostra_recortada, 'b-', 1:tam_min, referencia_recortada, 'r--', 'LineWidth', 1.5);
    title('Comparação: Sinal Medido vs. Referência');
    xlabel('Índice da Amostra');
    ylabel('Amplitude');
    legend('Sinal Medido', 'Sinal de Referência');
    grid on;

    % Subplot 2: Gráfico do offset ponto a ponto
    subplot(3, 1, 2);
    plot(1:tam_min, diferenca_offset, 'g-', 'LineWidth', 1.5);
    hold on;
    plot([1, tam_min], [offset_medio, offset_medio], 'r--', 'LineWidth', 1.5);
    title(sprintf('Análise de Offset - Média: %.2f LSB', offset_medio));
    xlabel('Índice da Amostra');
    ylabel('Offset (LSB)');
    legend('Offset Instantâneo', 'Offset Médio');
    grid on;

    % Subplot 3: Histograma do offset
    subplot(3, 1, 3);
    hist(diferenca_offset, 20);
    title(sprintf('Distribuição do Offset - Desvio Padrão: %.2f LSB', offset_std));
    xlabel('Valor do Offset (LSB)');
    ylabel('Ocorrências');
    grid on;

    % Adicionar título principal à figura de análise de offset
##    ##sgtitle(sprintf('Análise Completa de Offset - Média: %.2f LSB, Máx: %.2f, Mín: %.2f', ...
##                   offset_medio, offset_max, offset_min), ...
##           'FontSize', 14, 'FontWeight', 'bold');

    % Imprimir a análise de offset no console
    printf("\n--- Análise de Offset ---\n");
    printf("Offset médio: %.4f LSB\n", offset_medio);
    printf("Desvio padrão do offset: %.4f LSB\n", offset_std);
    printf("Offset máximo: %.4f LSB\n", offset_max);
    printf("Offset mínimo: %.4f LSB\n", offset_min);
    printf("Excursão do offset (pico a pico): %.4f LSB\n", offset_max - offset_min);

    % Calcular o offset em termos de tensão (assumindo 5V de referência)
    offset_volts = offset_medio * (5.0 / 1023);
    printf("Offset médio em tensão: %.4f mV\n", offset_volts * 1000);
else
    % Mensagem se não houver dados suficientes
    text(0.5, 0.5, 'Dados insuficientes para análise de offset', ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
    printf("\nAVISO: Dados insuficientes para análise de offset!\n");
end


%%%%%%%%%%%%%%%%%%% ANÁLISE DE DNL (DIFFERENTIAL NON-LINEARITY) - REVISADA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Análise do erro de não linearidade diferencial usando método de histograma

% Criar uma nova figura para análise de DNL
figure(4);

% Calculando DNL usando método de histograma
% 1. Criar histograma dos códigos obtidos
histograma = histc(primeiraAmostraVetorCompleto, 0:1023);

% 2. Calcular o DNL - variação entre os passos de quantização
% DNL = (contagem_real - contagem_ideal) / contagem_ideal
media_histograma = mean(histograma(histograma > 0)); % Média considerando apenas códigos presentes
dnl = (histograma - media_histograma) / media_histograma;

% Tratamento para códigos ausentes (missing codes)
dnl(histograma == 0) = -1; % DNL = -1 para missing codes

% Calculando estatísticas do DNL
dnl_sem_ausentes = dnl(histograma > 0);
dnl_medio = mean(dnl_sem_ausentes);
dnl_max = max(dnl);
dnl_min = min(dnl_sem_ausentes); % Considerando apenas códigos presentes
dnl_std = std(dnl_sem_ausentes);
dnl_pp = max(dnl) - min(dnl_sem_ausentes);

% Subplot 1: DNL vs. Código
subplot(2, 1, 1);
stem(0:1023, dnl, 'LineWidth', 1.0);
hold on;
plot([0, 1023], [0, 0], 'r--', 'LineWidth', 1.5);  % Linha de referência em 0
xlim([0, 1023]);
ylim([min(-1.2, min(dnl)*1.1), max(0.5, max(dnl)*1.1)]);
title(sprintf('DNL vs. Código - Máx: %.4f LSB, Mín: %.4f LSB', dnl_max, dnl_min));
xlabel('Código (0-1023)');
ylabel('DNL (LSB)');
grid on;

% Subplot 2: Histograma do DNL (excluindo missing codes)
subplot(2, 1, 2);
hist(dnl_sem_ausentes, 25);
title(sprintf('Distribuição do DNL - Média: %.4f LSB, Desvio Padrão: %.4f LSB', dnl_medio, dnl_std));
xlabel('Valor do DNL (LSB)');
ylabel('Ocorrências');
grid on;

% Adicionar título principal à figura de análise de DNL
#sgtitle('Análise de Differential Non-Linearity (DNL) - Método de Histograma', 'FontSize', 14, 'FontWeight', 'bold');

% Imprimir análise de DNL no console
printf("\n--- Análise de DNL (Differential Non-Linearity) - Revisada ---\n");
printf("DNL médio: %.4f LSB\n", dnl_medio);
printf("DNL máximo: %.4f LSB\n", dnl_max);
printf("DNL mínimo: %.4f LSB (códigos presentes)\n", dnl_min);
printf("DNL pico a pico: %.4f LSB\n", dnl_pp);
printf("Desvio padrão do DNL: %.4f LSB\n", dnl_std);

% Calcular percentagem de códigos que são missing codes (DNL = -1)
missing_codes_count = sum(histograma == 0);
missing_codes_percent = (missing_codes_count / length(0:1023)) * 100;

printf("Número de missing codes: %d (%.2f%%)\n", missing_codes_count, missing_codes_percent);

%%%%%%%%%%%%%%%%%%% ANÁLISE DE INL (INTEGRAL NON-LINEARITY) - REVISADA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Análise do erro de não linearidade integral como acumulação do DNL

% Criar uma nova figura para análise de INL
figure(5);

% Calcular o INL como soma cumulativa do DNL
% O DNL já foi calculado na seção anterior
inl = cumsum(dnl);

% Ajuste end-point para garantir que o INL comece e termine em zero (best-fit line)
% Encontramos o primeiro e último código presente
primeiro_indice = find(histograma > 0, 1, 'first');
ultimo_indice = find(histograma > 0, 1, 'last');

% Aplicamos uma correção linear para garantir que o INL seja zero nos extremos
% Isso é equivalente ao método "end-point fit"
codigos = 0:1023;
correcao = zeros(size(codigos));
if (primeiro_indice < ultimo_indice)
    % Linha que passa pelos pontos extremos do INL
    inclinacao = (inl(ultimo_indice) - inl(primeiro_indice)) / (ultimo_indice - primeiro_indice);
    intercepto = inl(primeiro_indice) - inclinacao * primeiro_indice;

    % Linha de correção
    correcao = inclinacao * codigos + intercepto;

    % INL corrigido (end-point fit)
    inl = inl - correcao;
endif

% Calculando estatísticas do INL (apenas para códigos presentes)
inl_presente = inl;
inl_presente(histograma == 0) = NaN; % Para não considerar nos cálculos
inl_sem_nan = inl_presente(~isnan(inl_presente));

inl_medio = mean(inl_sem_nan);
inl_max = max(inl_sem_nan);
inl_min = min(inl_sem_nan);
inl_std = std(inl_sem_nan);
inl_pp = inl_max - inl_min;  % Pico a pico

% Subplot 1: INL vs. Código
subplot(2, 1, 1);
plot(0:1023, inl_presente, 'b-', 'LineWidth', 1.5);
hold on;
plot([0, 1023], [0, 0], 'r--', 'LineWidth', 1);  % Linha de referência em 0
xlim([0, 1023]);
if (~isempty(inl_sem_nan))
    ylim([min(-0.5, min(inl_sem_nan)*1.1), max(0.5, max(inl_sem_nan)*1.1)]);
endif
title(sprintf('INL vs. Código - Pico a Pico: %.4f LSB', inl_pp));
xlabel('Código (0-1023)');
ylabel('INL (LSB)');
grid on;

% Subplot 2: Histograma do INL
subplot(2, 1, 2);
if (~isempty(inl_sem_nan))
    hist(inl_sem_nan, 25);
endif
title(sprintf('Distribuição do INL - Média: %.4f LSB, Desvio Padrão: %.4f LSB', inl_medio, inl_std));
xlabel('Valor do INL (LSB)');
ylabel('Ocorrências');
grid on;

% Adicionar título principal à figura de análise de INL
##sgtitle('Análise de Integral Non-Linearity (INL) - Método Cumulativo', 'FontSize', 14, 'FontWeight', 'bold');

% Imprimir análise de INL no console
printf("\n--- Análise de INL (Integral Non-Linearity) - Revisada ---\n");
printf("INL médio: %.4f LSB\n", inl_medio);
printf("INL máximo: %.4f LSB\n", inl_max);
printf("INL mínimo: %.4f LSB\n", inl_min);
printf("INL pico a pico: %.4f LSB\n", inl_pp);
printf("Desvio padrão do INL: %.4f LSB\n", inl_std);

% Avaliação da qualidade do conversor com base no INL pico a pico
if (inl_pp <= 0.5)
    printf("Qualidade do conversor (INL): Excelente (INL p-p <= 0.5 LSB)\n");
elseif (inl_pp <= 1.0)
    printf("Qualidade do conversor (INL): Muito boa (INL p-p <= 1.0 LSB)\n");
elseif (inl_pp <= 1.5)
    printf("Qualidade do conversor (INL): Boa (INL p-p <= 1.5 LSB)\n");
elseif (inl_pp <= 2.0)
    printf("Qualidade do conversor (INL): Razoável (INL p-p <= 2.0 LSB)\n");
else
    printf("Qualidade do conversor (INL): Precisa de melhorias (INL p-p > 2.0 LSB)\n");
endif
