% Monitor Serial para Dados ADC - versão adaptada
% Requer pacote instrument-control: pkg install -forge instrument-control

% Carrega o pacote
pkg load instrument-control;

% Configurações
porta = 'COM5';
baudrate = 115200;  % Ajustado para corresponder ao Arduino

% Variáveis para armazenar dados
buffer = [];
linhaAtual = '';
adcValores = [];
direcao = -1;

% Informações
disp('=== MONITOR SERIAL PARA LEITURA ADC ===');
printf('Porta: %s, Baudrate: %d\n', porta, baudrate);
disp('Pressione Ctrl+C para encerrar');

% Tenta abrir a porta
try
  % Abre a porta
  s = serial(porta, baudrate);

  % Avisa que está conectado
  disp('Porta conectada!');
  disp('Aguardando dados...');

  figure('Position', [100, 100, 800, 500]);

  % Loop de leitura
  while (1)
    % Lê caracteres disponíveis
    [dado, count] = srl_read(s, 100);

    % Se recebeu dados
    if (count > 0)
      % Processa cada caractere
      for i = 1:length(dado)
        % Se é um caractere de nova linha, processa a linha
        if (dado(i) == 10 || dado(i) == 13)  % LF ou CR
          % Se a linha não está vazia
          if (length(linhaAtual) > 0)
            % Verifica se é informação sobre a direção
            if (strncmp(linhaAtual, 'Direção', 7))
              if (strfind(linhaAtual, '1'))
                direcao = 1;  % subida
                disp('Direção: SUBIDA');
              else
                direcao = 0;  % descida
                disp('Direção: DESCIDA');
              endif
            else
              % Tenta converter valor para número
              try
                valor = str2num(linhaAtual);
                if (!isempty(valor) && !isnan(valor))
                  % Adiciona ao buffer
                  adcValores = [adcValores; valor];
                endif
              catch
                % Ignora linhas que não são números
              end_try_catch
            endif

            % Limpa a linha atual
            linhaAtual = '';
          endif
        else
          % Adiciona o caractere à linha atual
          linhaAtual = [linhaAtual, char(dado(i))];
        endif
      endfor

      % Quando coletou dados suficientes, plota o gráfico
      if (length(adcValores) >= 100)
        % Plota os dados
        clf;  % Limpa figura atual
        plot(adcValores, 'b-', 'LineWidth', 1.5);
        grid on;
        title('Leitura de Valores ADC');
        xlabel('Índice');
        ylabel('Valor ADC (0-1023)');
        if (direcao == 1)
          text(10, 50, 'Direção: SUBIDA', 'Color', 'green', 'FontSize', 12);
        elseif (direcao == 0)
          text(10, 50, 'Direção: DESCIDA', 'Color', 'red', 'FontSize', 12);
        endif
        xlim([0, length(adcValores)]);
        ylim([0, 1024]);
        drawnow;

        % Mantém apenas os últimos 1000 valores
        if (length(adcValores) > 1000)
          adcValores = adcValores(end-999:end);
        endif
      endif
    endif

    % Pequena pausa para não sobrecarregar o CPU
    pause(0.01);
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
