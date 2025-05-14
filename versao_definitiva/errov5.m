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

%%%%%%%%%%%%%%%%%%% GERANDO O VETOR DE REFERÊNCIA MODIFICADO (5 a 400) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Criando apenas a faixa de 5 a 400
vetorReferencia = 5:100;

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

%%%%%%%%%%%%%%%%%%% FILTRAGEM DOS DADOS NA FAIXA 5-100 %%%%%%%%%%%%%%%%%%%%%%%%%%%
% Filtrando apenas os valores da amostra que estão dentro da faixa de interesse (5-100)
indicesFaixa = find(primeiraAmostraVetorCompleto >= 5 & primeiraAmostraVetorCompleto <= 100);
amostraFiltrada = primeiraAmostraVetorCompleto(indicesFaixa);

fprintf('Tamanho do vetor de amostra filtrado (5-50): %d\n', length(amostraFiltrada));

%%%%%%%%%%%%%%%%%%% MISSING CODE - FAIXA 5-100 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Código para análise de missing code na faixa de 5 a 400

% Encontrar os missing codes (valores presentes em vetorReferencia mas ausentes em amostraFiltrada)
missingCodes = setdiff(vetorReferencia, amostraFiltrada);

% Criar um vetor de ocorrência (1 se o código está presente, 0 se está ausente)
ocorrencia = ones(size(vetorReferencia));
for i = 1:length(missingCodes)
    indices = find(vetorReferencia == missingCodes(i));
    ocorrencia(indices) = 0;
end

% Análise dos missing codes
numMissingCodes = length(missingCodes);
percentualMissing = (numMissingCodes / length(vetorReferencia)) * 100;

% Encontrar os índices dos missing codes no vetor de referência
indicesMissing = [];
for i = 1:length(missingCodes)
    indicesMissing = [indicesMissing, find(vetorReferencia == missingCodes(i))];
end

% Gráfico complementar mostrando apenas os missing codes
figure(1);
stem(missingCodes, ones(size(missingCodes)), 'r', 'LineWidth', 1.5);
title(sprintf('Missing Codes (5-100): %d valores ausentes (%.2f%%)', numMissingCodes, percentualMissing));
xlabel('Valor');
ylabel('Missing (1)');
xlim([5 100]);
grid on;

% Imprimir a análise no console
printf("\n--- Análise de Missing Codes (Faixa 5-50) ---\n");
printf("Total de códigos de referência: %d\n", length(vetorReferencia));
printf("Total de códigos de referência únicos: %d\n", length(unique(vetorReferencia)));
printf("Total de códigos na amostra filtrada: %d\n", length(amostraFiltrada));
printf("Número de missing codes únicos: %d\n", numMissingCodes);
printf("Percentual de missing codes: %.2f%%\n", percentualMissing);

%%%%%%%%%%%%%%%%%%% ANÁLISE DE OFFSET - FAIXA 5-100 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Visualização do sinal de referência digital segurado e do sinal amostrado digital segurado

% Criar uma nova figura para visualização dos sinais
figure(2);

% Criar o sinal de referência linear para a faixa 5-100
sinalReferenciaLinear = 5:100;

% Filtrar apenas os dados da amostra na faixa 5-100
indicesFaixa = find(primeiraAmostraVetorCompleto >= 5 & primeiraAmostraVetorCompleto <= 100);
amostraFaixa = primeiraAmostraVetorCompleto(indicesFaixa);

% Certifique-se de que a amostra esteja ordenada (para visualização em degraus)
amostraFaixa = sort(amostraFaixa);

% Criar representação em degraus do sinal de referência (VERMELHA)
x_degraus_ref = [];
y_degraus_ref = [];

for i = 1:length(sinalReferenciaLinear)
    % Adicionar dois pontos para cada valor: início e fim do degrau
    x_degraus_ref = [x_degraus_ref, i+4, i+5]; % i+4 para começar em 5
    y_degraus_ref = [y_degraus_ref, sinalReferenciaLinear(i), sinalReferenciaLinear(i)];
end

% Criar representação em degraus do sinal digital (AZUL)
x_degraus = [];
y_degraus = [];

if length(amostraFaixa) > 0
    % Adicionar o primeiro ponto
    x_degraus = [x_degraus, 5];
    y_degraus = [y_degraus, amostraFaixa(1)];

    % Para cada amostra, adicionar dois pontos: um para concluir o degrau atual
    % e outro para iniciar o próximo degrau
    for i = 2:length(amostraFaixa)
        % Ponto final do degrau anterior (mesmo valor Y, posição X da próxima amostra)
        x_degraus = [x_degraus, 5 + i - 1];
        y_degraus = [y_degraus, amostraFaixa(i-1)];

        % Ponto inicial do próximo degrau (novo valor Y, mesma posição X)
        x_degraus = [x_degraus, 5 + i - 1];
        y_degraus = [y_degraus, amostraFaixa(i)];
    end

    % Adicionar o último ponto para completar o último degrau
    x_degraus = [x_degraus, 5 + length(amostraFaixa)];
    y_degraus = [y_degraus, amostraFaixa(end)];

    % Plotar os dois sinais em uma única figura
    plot(x_degraus_ref, y_degraus_ref, 'r-', 'LineWidth', 2);
    hold on;
    plot(x_degraus, y_degraus, 'b-', 'LineWidth', 2);

    % Adicionar pontos de amostragem para melhor visualização
    plot(5:5+length(amostraFaixa)-1, amostraFaixa, 'bo', 'MarkerSize', 4, 'MarkerFaceColor', 'b');

    % Configurar o gráfico
    title('Comparação: Sinal de Referência Segurado vs. Sinal Digital Segurado');
    xlabel('Código');
    ylabel('Amplitude');
    legend('Sinal de Referência Segurado (5-100)', 'Sinal Digital Segurado', 'Pontos de Amostragem');
    grid on;
    xlim([5, min(50, 5 + length(amostraFaixa) + 5)]);  % Limite X ajustado para melhor visualização

    % Calcular as estatísticas de offset
    % Recorte os sinais para terem o mesmo comprimento
    tam_min = min(length(sinalReferenciaLinear), length(amostraFaixa));
    ref_recortado = sinalReferenciaLinear(1:tam_min);
    amostra_recortada = amostraFaixa(1:tam_min);

    % Calcular o offset (erro)
    offset = amostra_recortada - ref_recortado;

    % Estatísticas do offset
    offset_medio = mean(offset);
    offset_std = std(offset);
    offset_max = max(offset);
    offset_min = min(offset);
    offset_pp = offset_max - offset_min;

    % Imprimir a análise de offset no console
    printf("\n--- Análise de Offset: Referência vs. Digital Segurado (5-100) ---\n");
    printf("Offset médio: %.4f LSB\n", offset_medio);
    printf("Desvio padrão do offset: %.4f LSB\n", offset_std);
    printf("Offset máximo: %.4f LSB\n", offset_max);
    printf("Offset mínimo: %.4f LSB\n", offset_min);
    printf("Excursão do offset (pico a pico): %.4f LSB\n", offset_pp);

    % Calcular o offset em termos de tensão (assumindo 5V de referência)
    offset_volts = offset_medio * (5.0 / 1023);
    printf("Offset médio em tensão: %.4f mV\n", offset_volts * 1000);

    % Contar repetições no sinal (valores "segurados")
    valores_unicos = unique(amostraFaixa);
    repeticoes = length(amostraFaixa) - length(valores_unicos);

    printf("Valores repetidos (segurados): %d (%.2f%% do total)\n",
           repeticoes, (repeticoes/length(amostraFaixa))*100);
else
    % Mensagem se não houver dados suficientes
    text(0.5, 0.5, 'Dados insuficientes para análise', ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
    printf("\nAVISO: Dados insuficientes para análise!\n");
end

%%%%%%%%%%%%%%%%%%% ANÁLISE DE DNL e INL - FAIXA 5-100 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Análise do erro de não linearidade diferencial e integral com metodologia correta

% Criar uma nova figura para análise combinada
figure(3);

% Histograma de ocorrências por código na faixa 5-100
histograma = histc(amostraFiltrada, 5:100);

% Quantidade total de amostras na faixa
total_amostras = sum(histograma);

% Quantidade de códigos possíveis na faixa 5-100
N = length(5:100); % 396 códigos

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
stem(5:100, dnl, 'b', 'LineWidth', 1.0);
hold on;
plot([5, 100], [0, 0], 'r--', 'LineWidth', 1.5);  % Linha de referência em 0
xlim([5, 100]);
title(sprintf('DNL vs. Código (5-100) - Máx: %.4f LSB, Mín: %.4f LSB', dnl_max, dnl_min));
ylabel('DNL (LSB)');
grid on;

% Visualização do INL
subplot(2, 1, 2);
plot(5:100, inl, 'r-', 'LineWidth', 1.5);
hold on;
plot([5, 100], [0, 0], 'b--', 'LineWidth', 1);  % Linha de referência em 0
xlim([5, 100]);
title(sprintf('INL vs. Código (5-100) - Pico a Pico: %.4f LSB', inl_pp));
xlabel('Código (5-100)');
ylabel('INL (LSB)');
grid on;

% Imprimir análise no console
printf("\n--- Análise de DNL (Faixa 5-100) ---\n");
printf("Total de amostras na faixa: %d\n", total_amostras);
printf("Média teórica por código: %.4f amostras/código\n", media_teorica);
printf("DNL médio: %.4f LSB\n", dnl_medio);
printf("DNL máximo: %.4f LSB\n", dnl_max);
printf("DNL mínimo (códigos presentes): %.4f LSB\n", dnl_min);
printf("Desvio padrão do DNL: %.4f LSB\n", dnl_std);

printf("\n--- Análise de INL (Faixa 5-100) ---\n");
printf("INL médio: %.4f LSB\n", inl_medio);
printf("INL máximo: %.4f LSB\n", inl_max);
printf("INL mínimo: %.4f LSB\n", inl_min);
printf("INL pico a pico: %.4f LSB\n", inl_pp);
printf("Desvio padrão do INL: %.4f LSB\n", inl_std);

% Avaliação da qualidade baseada nos valores da faixa 5-100
printf("\n--- Avaliação da Qualidade do ADC (Faixa 5-100) ---\n");
if (dnl_max <= 0.5 && inl_pp <= 0.5)
    printf("Qualidade do conversor: Excelente (DNL máx <= 0.5 LSB, INL p-p <= 0.5 LSB)\n");
elseif (dnl_max <= 1.0 && inl_pp <= 1.0)
    printf("Qualidade do conversor: Muito boa (DNL máx <= 1.0 LSB, INL p-p <= 1.0 LSB)\n");
elseif (dnl_max <= 1.5 && inl_pp <= 1.5)
    printf("Qualidade do conversor: Boa (DNL máx <= 1.5 LSB, INL p-p <= 1.5 LSB)\n");
else
    printf("Qualidade do conversor: Precisa de melhorias (DNL máx > 1.5 LSB ou INL p-p > 1.5 LSB)\n");
endif

% Verificar presença de missing codes na faixa 5-100
missing_codes_count = sum(histograma == 0);
if (missing_codes_count > 0)
    printf("ATENÇÃO: %d missing codes detectados na faixa 5-100 (%.2f%% do total)\n",
           missing_codes_count, missing_codes_count/N*100);
else
    printf("Missing codes na faixa 5-100: Nenhum detectado (conversor é monotônico na faixa)\n");
endif
