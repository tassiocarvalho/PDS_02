% Visualização em tempo real de dados seriais - COM5
% Este script monitora a porta COM5 e plota os dados em tempo real
% Certifique-se de ter o pacote instrument-control instalado
% pkg install -forge instrument-control

% Limpar variáveis e fechar figuras
clear all;
close all;
clc;

% Verifica se o pacote instrument-control está carregado
pkg load instrument-control;

% Configurações da porta serial
porta = 'COM5';
baudrate = 115200;

% Configurações do gráfico
num_amostras = 1000;  % Número de amostras a serem exibidas
dados = zeros(1, num_amostras);
tempo = 1:num_amostras;

% Configura o gráfico
figure('Name', 'Visualização ADC em Tempo Real', 'NumberTitle', 'off');
h = plot(tempo, dados);
ylim([0 1023]);  % Limite para ADC de 10 bits (0-1023)
xlabel('Amostras');
ylabel('Valor ADC');
title('Leitura ADC em Tempo Real - COM5');
grid on;

% Inicializa a porta serial
try
  s = serial(porta, baudrate);
  srl_flush(s);
  
  fprintf('Conectado à porta %s com sucesso.\n', porta);
  fprintf('Pressione Ctrl+C para encerrar a aquisição.\n');
  
  % Loop principal para aquisição contínua
  ultima_atualizacao = time();
  while true
    % Tenta ler uma linha da porta serial
    try
      linha = srl_read(s, "\n");
      if (!isempty(linha))
        % Converte a string para número
        valor = str2double(strtrim(linha));
        
        % Atualiza o vetor de dados (desloca e adiciona novo valor)
        dados = [dados(2:end), valor];
        
        % Verifica se passaram 3 segundos desde a última atualização
        tempo_atual = time();
        if (tempo_atual - ultima_atualizacao >= 3)
          % Atualiza o gráfico
          set(h, 'YData', dados);
          drawnow;
          titulo = sprintf('Leitura ADC em Tempo Real - COM5 (Atualizado: %s)', strftime('%H:%M:%S', localtime(tempo_atual)));
          title(titulo);
          ultima_atualizacao = tempo_atual;
          fprintf('Gráfico atualizado às %s\n', strftime('%H:%M:%S', localtime(tempo_atual)));
        endif
      endif
    catch
      % Ignora erros de leitura
    end_try_catch
  endwhile
  
catch
  fprintf('Erro ao abrir a porta serial %s.\n', porta);
  fprintf('Verifique se:\n');
  fprintf(' - A porta está conectada\n');
  fprintf(' - A porta não está sendo usada por outro programa\n');
  fprintf(' - Você tem permissão para acessar a porta\n');
  fprintf(' - O pacote instrument-control está instalado (pkg install -forge instrument-control)\n');
end_try_catch

% Limpa ao finalizar
try
  if (exist('s', 'var'))
    if (s != -1)
      srl_close(s);
      clear s;
    endif
  endif
catch
  % Ignora erros ao fechar
end_try_catch

fprintf('Aquisição finalizada.\n');