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
sgtitle(sprintf('Análise Completa de Missing Codes - %.2f%% ausentes', percentualMissing), 'FontSize', 14, 'FontWeight', 'bold');

% Imprimir a análise no console
printf("\n--- Análise de Missing Codes ---\n");
printf("Total de códigos de referência: %d\n", length(vetorReferencia));
printf("Total de códigos de referência únicos: %d\n", length(unique(vetorReferencia)));
printf("Total de códigos na amostra: %d\n", length(primeiraAmostraVetorCompleto));
printf("Número de missing codes únicos: %d\n", numMissingCodes);
printf("Percentual de missing codes: %.2f%%\n", percentualMissing);

