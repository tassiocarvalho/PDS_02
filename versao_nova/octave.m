% Fechar qualquer figura aberta e limpar a tela
close all;
clear;
clc;

% Configurações iniciais
comPort = 'COM5';       % Porta COM do Arduino
baudRate = 2000000;     % Mesma taxa usada no Arduino (2Mbps)
maxSamples = 2046;      % Número de amostras (1023 subida + 1023 descida)
updateTime = 5;         % Tempo em segundos entre atualizações
voltRef = 5;            % Referência de tensão (5V)
resolution = 1023;      % Resolução do ADC (10 bits: 2^10-1)

% Tenta abrir a porta serial
try
    serialObj = serial(comPort, 'BaudRate', baudRate);
    fopen(serialObj);
    disp(['Porta ', comPort, ' aberta com sucesso!']);
catch
    error(['Não foi possível abrir a porta ', comPort, '. Verifique se o Arduino está conectado corretamente.']);
end

% Cria a figura
fig = figure('Name', 'Sinal ADC Arduino ATmega2560', 'NumberTitle', 'off');
h = plot(0, 0, 'r-', 'LineWidth', 1.5);
grid on;
title('Sinal Triangular Digitalizado (ATmega2560)');
xlabel('Amostras');
ylabel('Tensão (V)');
xlim([0 maxSamples]);
ylim([0 voltRef]);

% Loop para atualizar o plot a cada 5 segundos
try
    while ishandle(fig)
        % Limpa o buffer de entrada
        if serialObj.BytesAvailable > 0
            fread(serialObj, serialObj.BytesAvailable);
        end
        
        % Coleta os dados
        adcValues = [];
        disp('Coletando dados...');
        
        % Espera até que tenhamos maxSamples valores
        while length(adcValues) < maxSamples && ishandle(fig)
            if serialObj.BytesAvailable > 0
                line = fgetl(serialObj);
                if ~isempty(line) && ~isempty(str2num(line))
                    adcValues(end+1) = str2num(line);
                end
            end
            drawnow limitrate;  % Permite a interface atualizar
        end
        
        if ~ishandle(fig)
            break;
        end
        
        % Converte os valores do ADC para tensão
        voltage = (adcValues / resolution) * voltRef;
        
        % Atualiza o gráfico
        set(h, 'XData', 1:length(voltage), 'YData', voltage);
        drawnow;
        
        % Calcula e mostra a frequência do sinal
        disp(['Amostras coletadas: ', num2str(length(voltage))]);
        
        % Localiza os picos para estimar a frequência
        [peaks, locs] = findpeaks(voltage, 'MinPeakHeight', 0.8*voltRef);
        if length(locs) >= 2
            avgSamplesPerCycle = mean(diff(locs));
            % Frequência de amostragem = baudRate / (bits por byte * bytes por amostra)
            % Aproximação grosseira: assumindo frequência de amostragem de 10230 Hz
            estSamplingFreq = 10230;
            estSignalFreq = estSamplingFreq / avgSamplesPerCycle;
            disp(['Frequência estimada do sinal: ', num2str(estSignalFreq), ' Hz']);
        end
        
        % Aguarda o tempo de atualização
        disp(['Aguardando ', num2str(updateTime), ' segundos para próxima atualização...']);
        pause(updateTime);
    end
catch e
    disp(['Erro: ', e.message]);
end

% Fecha a porta serial quando terminar
if exist('serialObj', 'var') && isvalid(serialObj)
    fclose(serialObj);
    delete(serialObj);
    disp(['Porta ', comPort, ' fechada.']);
end