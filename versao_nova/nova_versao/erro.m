clc;
clear all;
close all;

%%%%%%%%%%%%%%%%%%% CHAMADA DAS BIBLIOTECAS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pkg load signal
pkg load instrument-control

%%%%%%%%%%%%%%%%%%% ALOCAÇÃO DE VARIÁVEIS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
MAX_RESULTS = 2047;
fs = 10230;
amostras = 2047;
raw = [];

countFirstTime = 0;
primeiraAmostraVetorCompleto = [];

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
    while (iteration_count < max_iterations && length(primeiraAmostraVetorCompleto) < 2047)
        tic;
        printf("Iteração %d: Tentando coletar dados...\n", iteration_count + 1);

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
                        data(end+1) = num_val;
                    endif
                endif
            catch
                % Continua se houver erro
                continue;
            end
        end

        % CORREÇÃO: Atualiza o vetor de amostras apenas se recebeu dados suficientes
        if (length(data) > 0)
            printf("Recebidos %d valores nesta iteração\n", length(data));
            if (countFirstTime == 0)
                primeiraAmostraVetorCompleto = data;
                printf("Vetor de primeira amostra preenchido com %d valores\n", length(primeiraAmostraVetorCompleto));
                if (length(primeiraAmostraVetorCompleto) >= 2047)
                    printf("Coleta de dados concluída!\n");
                    break;  % Sai do loop se já temos dados suficientes
                endif
            endif
            countFirstTime = countFirstTime + 1;

            raw = data;
            time = (0:length(raw)-1)/fs;
        else
            printf("Nenhum dado recebido nesta iteração\n");
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

    % CORREÇÃO: Verificação após sair do loop
    if (length(primeiraAmostraVetorCompleto) < 2047)
        printf("AVISO: Não foi possível coletar os 2047 valores desejados. Coletados: %d\n", length(primeiraAmostraVetorCompleto));

        % Se não temos dados suficientes, vamos usar os que temos
        if (length(primeiraAmostraVetorCompleto) == 0)
            printf("ERRO: Nenhum dado foi coletado! Usando valores aleatórios para teste.\n");
            % Gera alguns valores aleatórios para teste
            primeiraAmostraVetorCompleto = randi([0, 1023], 1, 500);
        endif
    endif

catch err
    % Captura exceções (como Ctrl+C)
    printf('Programa interrompido: %s\n', err.message);
end

%%%%%%%%%%%%%%%%%%% AJUSTE DO VETOR DE REFERÊNCIA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CORREÇÃO: Ajustar o vetor de referência para ter o mesmo tamanho que primeiraAmostraVetorCompleto
tamAmostra = length(primeiraAmostraVetorCompleto);
if (tamAmostra < length(vetorReferencia))
    printf("Ajustando vetor de referência para %d elementos\n", tamAmostra);
    vetorReferencia = vetorReferencia(1:tamAmostra);
elseif (tamAmostra > length(vetorReferencia))
    printf("AVISO: Amostra maior que referência! Ajustando amostra.\n");
    primeiraAmostraVetorCompleto = primeiraAmostraVetorCompleto(1:length(vetorReferencia));
    tamAmostra = length(primeiraAmostraVetorCompleto);
endif

%%%%%%%%%%%%%%%%%%% CÓDIGO DE ERRO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tamReferencia = length(vetorReferencia);

fprintf('Tamanho do vetor de amostra: %d\n', tamAmostra);
fprintf('Tamanho do vetor de referência: %d\n', tamReferencia);

% 1. Erro de offset
% O offset é calculado como a média das diferenças
offset = mean(primeiraAmostraVetorCompleto - vetorReferencia);
fprintf('Erro de offset: %.4f\n', offset);

% 2. Histograma de valores para detectar ausência de bit
% Vamos criar um histograma com os valores presentes no vetor de amostra
valorMaximo = max(max(primeiraAmostraVetorCompleto), max(vetorReferencia));
valorMinimo = min(min(primeiraAmostraVetorCompleto), min(vetorReferencia));
rangoValores = valorMinimo:valorMaximo;

% Contagem de ocorrências
histAmostra = histc(primeiraAmostraVetorCompleto, rangoValores);
histReferencia = histc(vetorReferencia, rangoValores);

% Valores ausentes: onde histAmostra é 0 mas histReferencia não é
valoresAusentes = rangoValores(histAmostra == 0 & histReferencia > 0);
fprintf('Número de valores ausentes: %d\n', length(valoresAusentes));
if ~isempty(valoresAusentes)
    fprintf('Primeiros 10 valores ausentes: ');
    fprintf('%d ', valoresAusentes(1:min(10, length(valoresAusentes))));
    fprintf('\n');
end

% 3. Erro de não linearidade diferencial (DNL)
% Para calcular o DNL, precisamos ordenar os valores
valoresOrdenadosAmostra = sort(primeiraAmostraVetorCompleto);
valoresOrdenadosReferencia = sort(vetorReferencia);

% Removendo duplicatas para calcular os degraus (LSB - Least Significant Bit)
valoresUnicosAmostra = unique(valoresOrdenadosAmostra);
valoresUnicosReferencia = unique(valoresOrdenadosReferencia);

% Calculando os degraus
degrausAmostra = diff(valoresUnicosAmostra);
degrausReferencia = diff(valoresUnicosReferencia);

% O LSB ideal é 1 para um conversor perfeito
lsbIdeal = 1;

% DNL é a diferença entre o tamanho real do degrau e o tamanho ideal
dnl = (degrausAmostra / mean(degrausAmostra)) - 1;

% 4. Erro de não linearidade integral (INL)
% INL é o acúmulo dos erros DNL
inl = cumsum(dnl);

% Plotando os resultados
figure(1);
subplot(2,2,1);
plot(valoresUnicosAmostra(1:end-1), dnl, 'b-');
title('Erro de Não Linearidade Diferencial (DNL)');
xlabel('Código de Saída');
ylabel('DNL (LSB)');
grid on;

subplot(2,2,2);
plot(valoresUnicosAmostra(1:end-1), inl, 'r-');
title('Erro de Não Linearidade Integral (INL)');
xlabel('Código de Saída');
ylabel('INL (LSB)');
grid on;

subplot(2,2,3);
plot(vetorReferencia, 'b-', 'LineWidth', 1);
hold on;
plot(primeiraAmostraVetorCompleto, 'r--', 'LineWidth', 1);
title('Comparação: Referência vs Amostra');
xlabel('Índice');
ylabel('Valor');
legend('Referência', 'Amostra');
grid on;

subplot(2,2,4);
stem(rangoValores, histAmostra > 0, 'filled', 'b');
hold on;
stem(rangoValores, histReferencia > 0, 'r');
title('Presença de Valores');
xlabel('Valor');
ylabel('Presente (1) / Ausente (0)');
legend('Amostra', 'Referência');
grid on;

% Estatísticas adicionais
fprintf('DNL máximo: %.4f LSB\n', max(abs(dnl)));
fprintf('INL máximo: %.4f LSB\n', max(abs(inl)));

% Verificação de ausência de bit
% Um bit ausente resultaria em um padrão específico de valores ausentes
codigosPresentes = unique(primeiraAmostraVetorCompleto);
codigosEsperados = unique(vetorReferencia);
codigosAusentes = setdiff(codigosEsperados, codigosPresentes);

% Análise de bits ausentes
if ~isempty(codigosAusentes)
    bitsAusentes = {};
    for i = 0:9  % Para um ADC de 10 bits (0-1023)
        mascara = 2^i;
        % CORREÇÃO: Use bitand com números inteiros
        codigosComBit = codigosPresentes(bitand(codigosPresentes, mascara) > 0);
        codigosSemBit = codigosPresentes(bitand(codigosPresentes, mascara) == 0);

        if isempty(codigosComBit) || isempty(codigosSemBit)
            bitsAusentes{end+1} = i;
        end
    end

    if ~isempty(bitsAusentes)
        fprintf('Possíveis bits ausentes: ');
        for i = 1:length(bitsAusentes)
            fprintf('bit %d ', bitsAusentes{i});
        end
        fprintf('\n');
    else
        fprintf('Nenhum bit específico parece estar ausente sistematicamente.\n');
    end
end

%%%%%%%%%%%%%%%%%%% FECHA A PORTA DE COMUNICAÇÃO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fclose(s1);
printf('Porta serial fechada.\n');
