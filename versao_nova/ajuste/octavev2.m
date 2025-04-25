% Monitor Serial Básico - versão mínima
% Requer pacote instrument-control: pkg install -forge instrument-control

% Carrega o pacote
pkg load instrument-control;

% Configurações
porta = 'COM5';
baudrate = 115200;

% Informações
disp('=== MONITOR SERIAL BÁSICO ===');
printf('Porta: %s, Baudrate: %d\n', porta, baudrate);
disp('Pressione Ctrl+C para encerrar');

% Tenta abrir a porta
try
  % Abre a porta
  s = serial(porta, baudrate);

  % Avisa que está conectado
  disp('Porta conectada!');
  disp('Aguardando dados...');

  % Loop de leitura - versão mais simples possível
  contador = 0;

  while (1)
    % Lê um byte por vez
    [dado, count] = srl_read(s, 1);

    % Se recebeu dados
    if (count > 0)
      % Se é um caractere de nova linha, processa a linha
      if (dado == "\n")
        % Para visualização mais limpa
        printf('\n');
      else
        % Imprime o caractere recebido
        printf('%s', dado);
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
