% Osciloscópio + Monitor Serial
% Mostra dados no terminal e plota gráfico em tempo real
% Otimizado para sinal de 5Hz
% Requer pacote instrument-control: pkg install -forge instrument-control

% Carrega o pacote
pkg load instrument-control;

% Configurações
porta = 'COM5';
baudrate = 2000000;
tamanho_buffer = 2048;  % Tamanho do buffer de dados para exibição
tempo_atualizacao = 0.00001;  % Atualiza o gráfico a cada 0.2 segundos (5 atualizações por segundo)

% Informações
disp('=== OSCILOSCÓPIO SERIAL + TERMINAL ===');
printf('Porta: %s, Baudrate: %d\n', porta, baudrate);
disp('Pressione Ctrl+C para encerrar');

% Cria figura para o osciloscópio
figure('Name', 'Osciloscópio Serial', 'Position', [50, 50, 800, 400]);
buffer_dados = zeros(1, tamanho_buffer);
linha_atual = plot(1:tamanho_buffer, buffer_dados);
xlabel('Amostras');
ylabel('Tensão (V)');
title('Osciloscópio Serial - Sinal em Tempo Real');
grid on;
ylim([0 5]);  % Limite para tensão de 0-5V
set(gca, 'FontSize', 10);

% Tenta abrir a porta
try
  % Abre a porta
  s = serial(porta, baudrate);

  % Avisa que está conectado
  disp('Porta conectada!');
  disp('Recebendo dados...');

  % Preparação para processamento de linhas
  buffer_linha = '';
  contador = 0;
  ultima_atualizacao = time();

  % Loop de leitura
  while (1)
    % Lê um byte por vez
    [dado, count] = srl_read(s, 1);

    % Se recebeu dados
    if (count > 0)
      % Se é um caractere de nova linha, processa a linha
      if (dado == "\n" || dado == "\r")
        if (length(buffer_linha) > 0)
          % Tenta converter para número
          valor = str2double(strtrim(buffer_linha));

          if (!isnan(valor))
            % Incrementa contador
            contador++;

            % Calcula tensão
            tensao = (valor / 1023) * 5;

            % Adiciona ao buffer de dados (deslocando valores antigos)
            buffer_dados = [buffer_dados(2:end), tensao];

            % Mostra no terminal
            printf('Valor %5d: ADC = %4d, Tensão = %.3f V\n', contador, valor, tensao);

            % Verifica se é hora de atualizar o gráfico
            tempo_atual = time();
            if (tempo_atual - ultima_atualizacao >= tempo_atualizacao)
              % Atualiza o gráfico
              set(linha_atual, 'YData', buffer_dados);
              titulo = sprintf('Osciloscópio Serial - %d amostras/s',
                              round(1/tempo_atualizacao));
              title(titulo);
              drawnow;
              ultima_atualizacao = tempo_atual;
            endif
          endif

          % Limpa o buffer
          buffer_linha = '';
        endif
      else
        % Adiciona caractere ao buffer da linha
        buffer_linha = [buffer_linha, dado];
      endif
    endif
  endwhile

catch err
  % Mostra erro de forma simples
  disp('Erro:');
  disp(err.message);
end_try_catch

% Fecha porta se estiver aberta
try
  if (exist('s', 'var'))
    srl_close(s);
    disp('Porta fechada');
  endif
catch
  % Ignora erros ao fechar
end_try_catch

disp('Programa encerrado');
