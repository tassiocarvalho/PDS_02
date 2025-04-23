% Fechar qualquer figura aberta e limpar a tela
close all;
clear;
clc;


% Configurações iniciais
baudRate = 2000000;     % Mesma taxa usada no Arduino (2Mbps)
maxSamples = 2046;      % Número de amostras (1023 subida + 1023 descida)
updateTime = 5;         % Tempo em segundos entre atualizações
voltRef = 5;            % Referência de tensão (5V)
resolution = 1023;      % Resolução do ADC (10 bits: 2^10-1)

% Lista as portas seriais disponíveis (varia entre Windows e Linux/Mac)
if ispc
    [~, result] = system('wmic path win32_pnpentity get caption | findstr "COM"');
    ports = strsplit(result, '\n');
    disp('Portas seriais disponíveis:');
    for i = 1:length(ports)
        if ~isempty(ports{i})
            disp(ports{i});
        end
    end
else
    disp('Em Linux/Mac, as portas seriais geralmente estão em /dev/tty*');
    if exist('/dev', 'dir')
        [~, result] = system('ls /dev/tty*');
        disp(result);
    end
end

% Solicita ao usuário a porta COM
comPort = input('Digite a porta COM do Arduino (ex: COM3): ', 's');

% Verifica se o pacote de comunicação serial está instalado
if exist('serial') ~= 2
    error('Pacote de comunicação serial não encontrado. No Octave, use: pkg install -forge instrument-control');
end

% Tenta abrir a porta serial
try
    serialObj = serial(comPort, 'BaudRate', baudRate);
    fopen(serialObj);
    disp(['Porta ', comPort, ' aberta com sucesso!']);
catch e
    disp(['Erro ao abrir a porta ', comPort, ': ', e.message]);
    disp('Alternativas:');
    disp('1. Verifique se o Arduino está conectado corretamente');
    disp('2. Verifique se a porta COM está correta');
    disp('3. Verifique se o pacote instrument-control está instalado (pkg install -forge instrument-control)');
    disp('4. Verifique se outro programa está usando a porta');
    disp('5. No Windows, verifique o Gerenciador de Dispositivos');
    disp('6. No Linux, verifique as permissões da porta (sudo chmod 666 /dev/ttyXXX)');
    error('Não foi possível abrir a porta serial');
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
