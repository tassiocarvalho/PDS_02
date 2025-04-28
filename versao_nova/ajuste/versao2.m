clc;
clear all;
close all;

pkg load signal
pkg load instrument-control

MAX_RESULTS = 2048;
fs = 10230;
amostras = 2048;               % Aumentado para capturar mais amostras de uma vez
raw = [];

s1 = serial("COM5");
set(s1, 'baudrate', 115200);
set(s1, 'bytesize', 8);
set(s1, 'parity', 'n');
set(s1, 'stopbits', 1);
set(s1, 'timeout', 0.5);       % Reduzido para maior responsividade
srl_flush(s1);
pause(0.5);                    % Reduzido para iniciar mais rápido

t = zeros(1, 100);
i = 1;

while(1)
    tmp = srl_read(s1, 1);
    if (isempty(tmp))
        break;
    endif
    t(i) = tmp;
    if (t(i) == 10)
        break;
    endif
    i = i + 1;
end

t = t(1:i);
c = char(t);
printf('recebido: %s', c);

% Configuração de figura com tamanho e posição otimizados
figure(1, 'position', [50, 50, 1200, 800]);  % Janela maior
h1 = subplot(3,1,1);
h2 = subplot(3,1,2);
h3 = subplot(3,1,3);

% Define configurações de visualização para melhor aparência
set(groot, 'defaultLineLineWidth', 1.5);     % Linhas mais grossas
set(groot, 'defaultAxesFontSize', 12);       % Fontes maiores

try
    while (1)
        tic;
        data = [];

        % Buffer de leitura melhorado
        buffer = '';
        bytes_read = 0;

        % Tenta ler múltiplos bytes de uma vez para melhor performance
        try
            raw_data = srl_read(s1, 4096);  % Lê um bloco maior de dados
            if (!isempty(raw_data))
                buffer = char(raw_data);
                lines = strsplit(buffer, '\n');

                for j = 1:length(lines)
                    if (!isempty(lines{j}))
                        num_val = str2num(lines{j});
                        if (!isempty(num_val))
                            data(end+1) = num_val;
                            if (length(data) >= amostras)
                                break;
                            endif
                        endif
                    endif
                endfor
            endif
        catch
            % Continua em caso de erro
        end

        if (length(data) > 0)
            raw = data;
            time = (0:length(raw)-1)/fs;

            % Primeiro subplot com estilo melhorado
            subplot(h1);
            plot(time, raw*5/1023, 'b-');
            xlabel('t(s)', 'FontWeight', 'bold');
            ylabel('Tensão (V)', 'FontWeight', 'bold');
            title('Sinal gerado x(t)', 'FontSize', 14);
            grid on;
            ylim([0 5]);  % Fixa o limite de 0-5V para melhor visualização

            % Segundo subplot
            subplot(h2);
            stem(raw, 'filled', 'MarkerSize', 4);
            xlabel('n', 'FontWeight', 'bold');
            ylabel('Valor ADC', 'FontWeight', 'bold');
            title('x[n]', 'FontSize', 14);
            grid on;
            ylim([0 1023]);  % Fixa o limite de 0-1023 para escala ADC

            % Terceiro subplot
            subplot(h3);
            stairs(raw, 'r-');
            xlabel('n', 'FontWeight', 'bold');
            ylabel('Valor ADC', 'FontWeight', 'bold');
            title('x[n] segurado', 'FontSize', 14);
            grid on;
            ylim([0 1023]);  % Fixa o limite de 0-1023 para escala ADC

            % Força atualização e desenho otimizado
            drawnow limitrate;  % Limita a taxa de atualização para evitar sobrecarga
        else
            printf("Nenhum dado recebido nesta iteração\n");
        end

        elapsed = toc;
        if (elapsed < 0.5)  % Reduzido para atualizar mais rápido
            pause(0.5 - elapsed);
        end

        printf('Amostras: %d, Tempo: %.2f s, Taxa: %.1f amostras/s\n',
               length(data), elapsed, length(data)/elapsed);
    end
catch err
    printf('Programa interrompido: %s\n', err.message);
end

fclose(s1);
printf('Porta serial fechada.\n');
