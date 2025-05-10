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
    plot(1:tam_min, amostra_recortada, 'b-', 1:tam_min, referencia_recortada, 'r--', 'LineWidth', 1.5);
    title('Comparação: Sinal Medido vs. Referência');
    xlabel('Índice da Amostra');
    ylabel('Amplitude');
    legend('Sinal Medido', 'Sinal de Referência');
    grid on;

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

%%%%%%%%%%%%%%%%%%% ANÁLISE DE DNL e INL - CORRIGIDA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Análise do erro de não linearidade diferencial e integral com metodologia correta

% Criar uma nova figura para análise combinada
figure(6);

% Histograma de ocorrências por código
histograma = histc(primeiraAmostraVetorCompleto, 0:1023);

% Quantidade total de amostras
total_amostras = sum(histograma);

% Quantidade de códigos possíveis
N = 1024; % 0-1023 = 1024 códigos

% Tamanho ideal de cada "bin" (idealmente todos iguais)
media_teorica = total_amostras / N;

% DNL: diferença relativa entre o tamanho real e o ideal
dnl = (histograma - media_teorica) / media_teorica;

% Para missing codes (códigos não presentes), DNL = -1
% Isso já está automaticamente correto no cálculo acima, pois histograma = 0 resultará em DNL = -1

% INL: soma cumulativa dos DNLs
inl = cumsum(dnl);

% Estatísticas DNL
dnl_presente = dnl(histograma > 0); % Apenas códigos presentes para estatísticas
dnl_medio = mean(dnl);
dnl_max = max(dnl);
dnl_min = min(dnl_presente); % Mínimo excluindo missing codes
dnl_std = std(dnl_presente);
dnl_pp = max(dnl) - min(dnl_presente);

% Estatísticas INL
inl_medio = mean(inl);
inl_max = max(inl);
inl_min = min(inl);
inl_std = std(inl);
inl_pp = inl_max - inl_min;

% Visualização do DNL
subplot(2, 1, 1);
stem(0:1023, dnl, 'b', 'LineWidth', 1.0);
hold on;
plot([0, 1023], [0, 0], 'r--', 'LineWidth', 1.5);  % Linha de referência em 0
xlim([0, 1023]);
title(sprintf('DNL vs. Código - Máx: %.4f LSB, Mín: %.4f LSB', dnl_max, dnl_min));
ylabel('DNL (LSB)');
grid on;

% Visualização do INL
subplot(2, 1, 2);
plot(0:1023, inl, 'r-', 'LineWidth', 1.5);
hold on;
plot([0, 1023], [0, 0], 'b--', 'LineWidth', 1);  % Linha de referência em 0
xlim([0, 1023]);
title(sprintf('INL vs. Código - Pico a Pico: %.4f LSB', inl_pp));
xlabel('Código (0-1023)');
ylabel('INL (LSB)');
grid on;

% Adicionar título principal à figura de análise
#sgtitle('Análise Corrigida de DNL e INL', 'FontSize', 14, 'FontWeight', 'bold');

% Imprimir análise no console
printf("\n--- Análise Corrigida de DNL ---\n");
printf("Total de amostras: %d\n", total_amostras);
printf("Média teórica por código: %.4f amostras/código\n", media_teorica);
printf("DNL médio: %.4f LSB\n", dnl_medio);
printf("DNL máximo: %.4f LSB\n", dnl_max);
printf("DNL mínimo (códigos presentes): %.4f LSB\n", dnl_min);
printf("Desvio padrão do DNL: %.4f LSB\n", dnl_std);

printf("\n--- Análise Corrigida de INL ---\n");
printf("INL médio: %.4f LSB\n", inl_medio);
printf("INL máximo: %.4f LSB\n", inl_max);
printf("INL mínimo: %.4f LSB\n", inl_min);
printf("INL pico a pico: %.4f LSB\n", inl_pp);
printf("Desvio padrão do INL: %.4f LSB\n", inl_std);

% Avaliação da qualidade baseada nos valores corrigidos
printf("\n--- Avaliação da Qualidade do ADC ---\n");
if (dnl_max <= 0.5 && inl_pp <= 0.5)
    printf("Qualidade do conversor: Excelente (DNL máx <= 0.5 LSB, INL p-p <= 0.5 LSB)\n");
elseif (dnl_max <= 1.0 && inl_pp <= 1.0)
    printf("Qualidade do conversor: Muito boa (DNL máx <= 1.0 LSB, INL p-p <= 1.0 LSB)\n");
elseif (dnl_max <= 1.5 && inl_pp <= 1.5)
    printf("Qualidade do conversor: Boa (DNL máx <= 1.5 LSB, INL p-p <= 1.5 LSB)\n");
else
    printf("Qualidade do conversor: Precisa de melhorias (DNL máx > 1.5 LSB ou INL p-p > 1.5 LSB)\n");
endif

% Verificar presença de missing codes
missing_codes_count = sum(histograma == 0);
if (missing_codes_count > 0)
    printf("ATENÇÃO: %d missing codes detectados (%.2f%% do total)\n",
           missing_codes_count, missing_codes_count/N*100);
else
    printf("Missing codes: Nenhum detectado (conversor é monotônico)\n");
endif
