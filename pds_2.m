% Visualizador de dados ADC em tempo real
% Criado para dados do ATmega2560 transmitidos a 1Mbps

% Configurações
porta_serial = 'COM6';           % Ajuste para sua porta (Windows: 'COM6', Linux: '/dev/ttyUSB0')
baud_rate = 1000000;             % Deve corresponder ao valor no código do ATmega2560
tempo_aquisicao = 1;             % Tempo de aquisição em segundos
tamanho_janela = 500;            % Número de pontos exibidos no gráfico
max_leituras = 15000;            % Número máximo de leituras por segundo

% Carregar pacote instrument-control
pkg load instrument-control;

% Abrir a porta serial - usando interface compatível com maioria das versões do Octave
s = serial(porta_serial, baud_rate);
srl_flush(s);

% Configurar gráfico
figure(1);
h = plot(zeros(1, tamanho_janela));
title('Leitura do ADC em Tempo Real');
xlabel('Amostras');
ylabel('Valor (0-1023)');
ylim([0 1023]);                   % Valores do ADC de 10 bits
grid on;

% Loop principal
try
  while true
    % Limpar buffer antes de cada nova aquisição
    bytes_disponiveis = srl_read(s, 0);
    if (numel(bytes_disponiveis) > 0)
      srl_flush(s);
    end
    
    % Preparar arrays para armazenar os dados
    dados = [];
    tempo_inicio = time();
    
    % Adquirir dados durante o tempo especificado
    while (time() - tempo_inicio) < tempo_aquisicao && length(dados) < max_leituras
      % Verificar se há pelo menos 2 bytes disponíveis
      bytes_disponiveis = srl_read(s, 0);
      if (numel(bytes_disponiveis) >= 2)
        % Ler high byte e low byte
        byte_alto = uint16(srl_read(s, 1));
        byte_baixo = uint16(srl_read(s, 1));
        
        % Combinar os bytes para formar um valor de 10 bits
        valor = bitshift(byte_alto, 8) + byte_baixo;
        
        % Armazenar o valor
        dados = [dados, valor];
      else
        % Pequena pausa para não sobrecarregar a CPU
        pause(0.001);
      end
    end
    
    % Se coletamos dados suficientes, atualizar o gráfico
    if ~isempty(dados)
      % Limitar o número de pontos exibidos
      if length(dados) > tamanho_janela
        dados_exibir = dados(end-tamanho_janela+1:end);
      else
        dados_exibir = dados;
      end
      
      % Atualizar o gráfico
      set(h, 'YData', dados_exibir);
      set(h, 'XData', 1:length(dados_exibir));
      drawnow;
      
      % Exibir estatísticas
      fprintf('Amostras coletadas: %d, Valor médio: %.2f, Min: %d, Max: %d\n', ...
              length(dados), mean(dados), min(dados), max(dados));
    else
      fprintf('Nenhum dado recebido neste intervalo\n');
    end
  end

catch e
  % Em caso de erro ou interrupção, fechar a porta serial
  fprintf('Programa interrompido: %s\n', e.message);
  
finally
  % Garantir que a porta serial seja fechada
  if exist('s', 'var')
    if (strcmp(typeinfo(s), 'octave_serial'))
      srl_close(s);
    endif
  endif
  fprintf('Porta serial fechada\n');
end