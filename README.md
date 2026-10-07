# Cidades do Brasil — 0.0.19

Protótipo Android em Godot 4.4.1, ARM64, Mobile/Vulkan, meta de 30 FPS.
Instale o APK sobre a versão anterior para manter a cidade; o pacote e a assinatura de teste são os mesmos.

## Interface e ferramentas

O HUD mostra caixa, população, dia econômico, saldo diário e demanda R/C/I. O botão de pausa fica no topo. O dock inferior agrupa Navegar, Rua de terra, Zonear, Infraestrutura, Mapas, Bulldozer e Opções, com ícones originais e destaque da ferramenta ativa. Confirmar, Cancelar e Traçado aparecem no contexto de construção.

Painéis laterais mostram consulta de lotes, escolha de uso/tamanho, instalações e camadas. O diagnóstico e os controles de salvamento ficam em Opções. Um dedo move ou seleciona no modo de obra; dois dedos giram/inclinam e a pinça aproxima.

## Ruas e zoneamento

Retas, diagonais e curvas se conectam a uma rua existente ou à entrada. Trechos isolados permanecem possíveis após demolição, mas não podem ser construídos inicialmente no vazio. O preço é R$ 40/m fictícios. Cruzamentos são derivados da geometria.

Zonear oferece Residencial, Comércio e Indústria. Automático tenta 10×12, 8×10, 6×8 e 4×6 m; os tamanhos Pequeno, Médio e Grande podem ser escolhidos. Lotes acompanham retas e curvas, com posições de frente a cada 2 m. Interseções com ruas/lotes e declives fortes são recusados. Limite: 128 lotes. Ainda não há pintura por arraste, lotes triangulares ou subdivisão.

Novas obras exigem demanda, acesso à entrada e água/energia e coleta/tratamento de esgoto suficientes. A capacidade é reservada quando a obra começa; depois ela leva 24 s ativos, pausando se perder serviços ou ligação externa. Zoneamento permanece gratuito. Instalações municipais são cobradas ao confirmar a obra.

## Infraestrutura e redes

O catálogo oferece três tamanhos de água, energia e esgoto, com modelos ajustados ao lote. Cobrança ocorre uma vez na confirmação; prévia ou recusa por falta de caixa não alteram dinheiro. A manutenção começa no primeiro fechamento diário após concluir a instalação, mesmo sem conexão. Demolir ou cancelar interrompe manutenção futura, sem reembolso.

| Instalação | Lote | Capacidade | Preço | Manutenção/dia |
| --- | --- | --- | --- | --- |
| Água pequena | 4×6 m | 30 | R$ 3.000 | R$ 20 |
| Água média | 6×8 m | 60 | R$ 6.000 | R$ 35 |
| Água grande | 10×12 m | 180 | R$ 15.000 | R$ 80 |
| Energia pequena | 4×6 m | 40 | R$ 4.000 | R$ 30 |
| Energia média | 6×8 m | 80 | R$ 8.000 | R$ 50 |
| Energia grande | 10×12 m | 240 | R$ 20.000 | R$ 120 |
| Esgoto pequeno | 4×6 m | 30 | R$ 3.500 | R$ 25 |
| Esgoto médio | 6×8 m | 60 | R$ 7.000 | R$ 45 |
| Esgoto grande | 10×12 m | 180 | R$ 17.500 | R$ 100 |

Valores e capacidades são fictícios. A ficha mostra caixa após compra e saldo diário previsto. A estimativa usa impostos do último dia menos manutenção de ruas e de todas as instalações autorizadas, incluindo obras em andamento; não antecipa arrecadação causada pela nova capacidade. No primeiro dia, a referência de impostos é zero. Compra de instalação é gasto pontual, separado do saldo recorrente. Instalações em construção não fornecem capacidade. A distribuição usa os componentes conectados do grafo das ruas: fontes numa rede não abastecem outra.

Moradia reserva sua capacidade de moradores nos três serviços. Comércio reserva vagas+1 de água e vagas×2 de energia. Indústria reserva vagas×2 de água e vagas×3 de energia. Esgoto reserva a mesma demanda abstrata da água. Em déficit, a ordem dos lotes define prioridade de atendimento. Prédios sem serviços mantêm geometria e moradores; empresas ficam inoperantes. Não há abandono automático.

O abastecimento legado de imóveis anteriores depende de conexão viária à entrada; não oferece capacidade a novas obras. Redes isoladas podem ter abastecimento local, mas novos empreendimentos e importação/exportação exigem conexão externa. Reconstruir uma rua reancora as frentes de lotes e recalcula serviços.

## Mapas técnicos

Água, energia, esgoto, fontes subterrâneas, acesso viário e uso do solo escondem prédios comuns, árvores e pedestres, com terreno neutro e lotes coloridos. Fontes do serviço selecionado permanecem visíveis. Traços mostram redes e ligações aos lotes. A legenda distingue atendimento, falta, legado, fontes e redes sem fonte. Voltar à cidade restaura a cena.

Os mapas mostram conexão/capacidade do modelo. Não representam fluxo físico, pressão, contaminação, estoque subterrâneo ou gargalos por cabo. A rede de esgoto acompanha ruas e utiliza estações de tratamento com descarte por infiltração abstrata. Veja `docs/referencias-e-direcao.md` para decisões e próximas etapas.

## Demolição

O bulldozer seleciona ruas entre cruzamentos/extremidades, prédios, instalações, obras e lotes. O alvo aparece vermelho e a confirmação descreve consequências, pausando a simulação durante a decisão. Cancelar não altera o modelo.

- Rua: remove somente o trecho destacado, preservando os demais, inclusive curvas. Prédios permanecem; sua frente pode ficar sem acesso. Redes e rotas são recalculadas. A entrada externa fixa não faz parte do alvo.
- Moradia: moradores desse imóvel saem da cidade com seus saldos; população e agentes são atualizados.
- Empresa: empregos são encerrados e seu caixa é transferido para o exterior da economia local.
- Instalação: capacidade deixa de existir na rede imediatamente.
- Manter zoneamento: disponível em lotes R/C/I; mantém geometria e uso como lote vazio aguardando demanda e serviços. Sem marcar, libera o terreno.

Não há custo de demolição nem reembolso nesta fase. O gasto histórico de ruas é mantido para que remover vias não crie dinheiro no salvamento. Referências de imóveis, empregos e viagens são renumeradas quando necessário; saldos e marcadores de pagamento dos demais moradores são mantidos. Uma rota rompida interrompe a viagem e faz o morador aguardar em casa; trajetos ainda possíveis são recalculados projetando a posição anterior no novo caminho.

## Economia e pedestres

Um dia econômico corresponde a 180 s ativos. Moradores chegam com R$ 300 externos e empresas com R$ 2.000 externos. Salário/produção acontecem após a visita ao trabalho e compras ao chegar à loja, no máximo uma vez por dia.

Indústria exporta R$ 180/trabalhador/dia, tributa 10% e paga até R$ 100. Comércio importa a R$ 5/unidade, vende por R$ 20 (R$ 2 de imposto) e paga até R$ 35. Tudo depende de caixa, estoque, trabalhadores, serviços e conexão necessária. Ruas custam manutenção de teto R$ 0,05/m/dia. Valores são fictícios e precisam de balanceamento.

Pedestres seguem as bordas das ruas e cruzam nas esquinas/junções a 1,65 m/s ativos. Consulta mostra identidade, idade, destino e saldo. Não há veículos ou colisão entre pedestres.

## Salvamento e migração

Salvamento automático e manual usa arquivo temporário validado e cópia anterior. O esquema externo continua 1; a rede utiliza `network_version=2`, gasto histórico e caminhos poligonais para trechos de curvas. Redes desconectadas e imóveis sem frente viária são aceitos e preservados após uma demolição válida.

Instalações anteriores sem catálogo são migradas para o modelo médio. As instalações da 0.0.15 preservam tamanho, preço já pago e manutenção. Não há cobrança retroativa. O registro municipal mantém gastos públicos já pagos inclusive após demolição.

Fixtures antigas verificam contas, moradores, obras e viagens. Estados de operação e componentes são derivados ao restaurar; a migração conserva o abastecimento legado apenas enquanto houver ligação à entrada.

## Executar, testar e exportar

Abra `project.godot` no Godot 4.4.1. Para testes:

```sh
GODOT_BIN=godot python3 tools/check_release.py
```

Para exportar Android, instale os templates do Godot 4.4.1, Java 17 e SDK/build-tools 34, configure `ANDROID_HOME` e `JAVA_HOME`, e execute `tools/configure_android.py`. Use a chave fornecida em `../test-signing/debug.keystore` apenas para este protótipo de teste.

```sh
GODOT_ANDROID_KEYSTORE_DEBUG_PATH=/caminho/test-signing/debug.keystore \
GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey \
GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android \
godot --headless --path . --export-debug Android build/cidades-brasil-prototipo-0.0.19.apk
```

O projeto contém testes de interface, geometria, demanda, contas, viagens, migração, serviços, demolição e topologia. Capturas desktop são evidência visual, não medição de desempenho no Android. O teste no S21 Ultra permanece pendente.

## Saneamento na 0.0.16

O mapa Fontes mostra três aquíferos subterrâneos fixos: Oeste (180), Leste (240) e Sul (180 unidades abstratas de vazão renovável). O centro do novo poço deve estar dentro de uma área. O terreno e as construções antigas não são deslocados. Cada aquífero aloca vazão aos poços concluídos com acesso viário, pela ordem dos lotes, inclusive quando pertencem a redes de ruas diferentes. Um poço pode ter oferta parcial ou zero; consultar o imóvel explica a limitação. Demolir ou desconectar um poço libera sua alocação. Poços em construção não alocam vazão; a prévia informa a disponibilidade atual, sujeita às outras obras.

As instalações de captação e tratamento usam equipamentos próprios, cujo funcionamento está incluído na manutenção; nesta etapa elas não consomem capacidade da rede elétrica. Essa simplificação permite construir a infraestrutura inicial sem dependência circular.

A ETE coleta, trata e encaminha o efluente para infiltração na mesma instalação. A conexão usa ruas; não há ferramenta separada de tubulação. A capacidade é reservada ao admitir uma obra R/C/I. A carga gerada considera imóveis concluídos com água disponível. O mapa separa reserva/capacidade, carga gerada, tratada local, externa legada e não tratada. Um lote recebe tratamento quando cabe integralmente na capacidade restante; a prioridade segue a ordem dos lotes. Ainda não há tanques de acumulação, transporte de esgoto, contaminação, doença ou fluxo volumétrico físico.

Sem esgoto, novos empreendimentos aguardam ou pausam a obra. Empresas concluídas sem os serviços param suas operações; moradores permanecem no imóvel. Restaurar atendimento permite retomada. A consulta explica qual serviço falta e o HUD conta os lotes com problemas de serviços/acesso. Avisos não incluem falta de demanda ou desemprego nesta etapa.

Migração: imóveis e lotes de versões anteriores recebem esgoto legado pela entrada; uma rede isolada perde essa isenção e precisa de tratamento local. Poços antigos preservam sua oferta, mesmo fora das novas áreas de aquífero. Novas construções não recebem essas isenções. Demolir mantendo zoneamento também remove as isenções da reconstrução. O submodelo residencial grava `sanitation_version=1`, `sewer_exempt` e `source_legacy`; recarregar não repete cobranças nem cria isenções novas.

Os testes incluem aquíferos compartilhados entre redes isoladas, atendimento antes/depois de demolir e reconstruir ETE, produção econômica suspensa, área seca recusada sem custo, migração autêntica da 0.0.15, persistência e seis mapas com interface por toque em 1280×640. Não há teste de desempenho no S21 Ultra nesta entrega.

## Alertas e orçamento na 0.0.17

Ícones vetoriais sobre os imóveis mostram falta de água, energia, esgoto, acesso, rede isolada, vazão limitada, espera por demanda ou empresa sem trabalhadores. Até três causas aparecem no marcador; “+” indica outras. Tocar abre a consulta e centraliza a câmera. Marcadores ficam ocultos nos mapas técnicos e sob painéis da interface. Durante construção/demolição, os gestos seguem a ferramenta ativa; o botão Avisos pode ser usado para sair dela e abrir o diagnóstico.

Avisos conta imóveis, não o número de causas. A lista informa ambos e oferece filtros Todos, Serviços, Acesso e Demanda. Sem rua, o diagnóstico prioriza reconstruir acesso, evitando sugestões de instalações antes da reconexão. O filtro Demanda inclui empresas operantes sem trabalhadores. A falta de demanda é informativa e não altera as regras de crescimento. Avisos são derivados e atualizados após mudanças e a cada segundo; não cobram valores nem alteram a cidade.

Consultar um lote mostra o diagnóstico, ações sugeridas e Ver causa no mapa. Os detalhes têm rolagem e os botões permanecem acessíveis. A lista também usa rolagem para atender cidades grandes. Selecionar uma entrada verifica endereço/uso novamente, portanto renumerar imóveis após demolição não redireciona um botão antigo para outro lote.

Orçamento, acessível em Opções → Economia ou pela lista de problemas, tem três abas:

- Último dia: impostos, manutenção de ruas, água, energia e esgoto efetivamente cobrados no fechamento. O histórico não muda quando uma instalação é demolida.
- Operação atual: estimativa considerando ruas existentes e instalações concluídas, inclusive isoladas/inoperantes. Mostra a quantidade por serviço.
- Obras autorizadas: inclui a manutenção futura das instalações ainda em construção. Mostra prontas e obras por serviço.

Estimativas usam os impostos do último dia e não garantem receitas futuras. Compras acumuladas de ruas/serviços são separadas das despesas recorrentes. O painel mostra impostos recebidos hoje e o tempo ativo até o fechamento. Salários, compras, importações e exportações são circulação privada, apresentados em detalhes; não são despesas da prefeitura.

O orçamento grava `budget_version=1`, `last_maintenance` e `last_breakdown_known`. A soma das categorias deve coincidir com a manutenção total. Saves anteriores não permitem reconstruir a composição histórica com segurança: a despesa é preservada como Não discriminado, com categorias não informadas, até o próximo fechamento diário produzir um registro novo. Caixa, moradores, obras, reservas e viagens são mantidos; não há cobrança por migrar.

Validação: testes de diagnóstico sem efeitos colaterais, resolução de serviços, renumeração, espera por demanda, orçamento realizado versus estimado, conservação de dinheiro, migração autêntica da 0.0.16, ícones e lista por toque, abas e controles em 1280×640. Capturas desktop reais complementam os testes. Android S21 Ultra permanece pendente de verificação no aparelho.


## Ruas e calçadas na 0.0.18

Menu Ruas: construir terra (R$ 40/m) ou asfalto com calçadas (R$ 80/m), e Asfaltar trecho existente (R$ 40/m). A seleção usa os trechos derivados entre junções ou extremidades do traçado original. Prévia sem efeitos no caixa; confirmação revalida o alvo, piso e saldo. Asfaltar novamente é recusado. Lotes, portas, ligações de serviços e posições das viagens são preservados. Construção e melhoria são imediatas nesta fase.

Pista mantém 7 m; base de calçada tem 9 m e cabe no recuo original de 4,6 m até a frente do lote. Todas as pistas cobrem a base de calçada nas junções. Superfícies são unidas por faixas e acompanham a terraplenagem existente. Travessias pintadas usam o mesmo grafo lateral dos pedestres e apenas braços asfaltados. Velocidade de caminhada: 1,35 m/s ativo; animação com menor cadência e oscilação. Não há veículos, semáforos nem preferência de passagem nesta versão.

A manutenção usa R$ 0,05/m/dia em terra e R$ 0,12/m/dia no asfalto, incluindo calçadas. O total é arredondado para cima uma vez por fechamento. `road_length()` continua retornando metros físicos; `maintenance_length()` retorna o equivalente ponderado consumido pelo orçamento existente. Cotação, previsão e manutenção realizada compartilham esses valores. As compras entram no histórico de ruas, não na circulação privada.

Persistência `network_version=3`, campo `surface` por traçado. Versões 1 e 2 seguem aceitas, com terra como padrão. Tipos de piso desconhecidos são rejeitados. Ao dividir para melhorar ou demolir, os trechos restantes conservam geometria e piso. Uma fixture gerada pela base 0.0.17 verifica a atualização com contas e viagens ativas.

Bulldozer calcula a perda de acesso em uma cópia da cidade. Mostra IDs de até oito lotes por categoria e o total: perda da rua frontal ou novo isolamento da entrada. A consulta não altera o estado real. A demolição efetiva ainda recalcula serviços, moradores e trajetos usando as regras existentes. A previsão é de acesso viário; não é uma estimativa de receita futura nem um inventário completo de efeitos indiretos nos serviços.

Testes novos: `road_upgrades.gd` (custo, recarga, mistura de pisos, manutenção real/prevista, impacto, curvas, saldo insuficiente e migração com viagens) e `road_upgrades_ui.gd` (toque real, confirmar/cancelar, repetição, salvamento, impacto e controles em 1280×640). Testes anteriores são mantidos. Capturas em `docs/screenshots/*018.png`; desempenho no S21 Ultra permanece pendente.


## Veículos e trânsito na 0.0.19

Cinco modelos procedurais: hatch (3,6 m), sedã (4,4 m), moto com piloto (2 m), caminhão leve de dois eixos (5,2 m) e caminhão grande rígido de três eixos (7,8 m). Rodas, vidros, carrocerias, faróis, lanternas e capacete são malhas locais. Cada tipo usa um MultiMesh, com cores por vértice e material padrão; não há um nó por veículo. Desenho interpola o progresso anterior/atual do passo de 0,1 s. A inclinação acompanha a altura da rua.

`vehicle_routes.gd` deriva rotas pelo grafo viário, com ligação virtual à frente do imóvel, duas faixas deslocadas 1,65 m para a direita e curvas nas junções. O trajeto inclui a entrada externa até x=-91. A ocupação retangular do modelo é amostrada a cada metro e precisa caber na união das pistas de 7 m. Rotas muito apertadas são recusadas, sem passar por calçadas ou lotes. Isso pode impedir caminhões grandes em determinadas curvas. Não é um solver de raio de giro mecânico nem simulação de carreta articulada.

`vehicle_traffic.gd` mantém até 24 viagens simultâneas. A cada quatro segundos tenta gerar uma viagem, alternando tipo e direção; o volume também é limitado pelo número de lotes. Carros e motos atendem R/C/I concluídos e ligados à entrada; caminhões leves, C/I; grandes, I. Empresas devem estar operantes. A seleção tenta até quatro destinos elegíveis por rodada. Entradas ocupadas adiam a geração. Rotas são armazenadas em cache até alteração da rede.

Limites em metros por segundo ativo: terra 4; asfalto até 8,5; compactos/sedãs 8, moto 8,5, leve 6,8, grande 5,8. Cruzamentos reduzem para 3,4 ou 2,6 nos grandes. Cada junção admite uma reserva de passagem, liberada depois que a traseira sai. Retângulos orientados com folga impedem sobreposição de veículos; não há ultrapassagem. Pedestres em travessias adiante fazem o veículo ceder, e pedestres não avançam sobre a carroceria já presente. O controlador é simplificado; não representa regras completas de preferência, sinalização ou capacidade de trânsito real.

Os cálculos de ocupação são compartilhados entre verificações de pedestres; caixas dos veículos e pedestres em travessia são calculados uma vez por passo de trânsito. Filas, curvas, cruzamentos X e fluxo de mão dupla têm testes. O limite e os lotes de desenho visam controlar o custo, mas não substituem medição no celular.

Persistência: novo campo opcional `traffic`, versão interna 1, dentro de `network_version=3`. Contém identificadores, endereços por coordenadas/uso, distâncias atual/anterior, velocidade, espera, reservas, contadores e relógios. Rotas são reconstruídas ao carregar e dados inválidos/ocupações sobrepostas são rejeitados. A fixture foi gerada pelo código 0.0.18. Versões sem trânsito começam sem veículos e preservam contas, moradores e pisos. A recarga retoma deterministicamente a simulação. Mudanças de rede preservam posição onde o trajeto continua válido; viagens inviáveis ou em conflito com novas reservas são canceladas. Ao demolir um imóvel, sua renumeração não transfere viagens para outro endereço.

Opções → Trânsito mostra contagens, modelo, velocidade e motivo da espera (fila, cruzamento ou travessia), e localiza os cinco tipos. Toque direto seleciona veículos. A câmera coloca o alvo na área livre ao lado do painel. Mapas técnicos ocultam os modelos; pausa inclui pedestres e veículos. Diagnóstico registra contagens e viagens concluídas/canceladas.

Esta fase cria trânsito local independente da economia: veículos não representam posse individual, carros não removem pedestres, caminhões não movimentam estoque real, e conclusão de viagem não gera receita ou pagamento. Não há garagens, semáforos, estacionamento, acidentes nem carretas. O próximo avanço pode ligar as entregas à cadeia produtiva, mantendo uma única fonte de movimentação financeira.

Validação nova em `tests/vehicle_traffic.gd` e `tests/vehicle_ui.gd`: tipos, vias de mão dupla, entrada ocupada, passagem em X, ausência de sobreposição, conclusão de fila, curvas, limite por piso, travessias, rejeição de saves inválidos, continuidade determinística, migração autêntica, demolição, cinco modelos renderizados, toque, pausa, mapas, salvamento e controles em 1280×640. Capturas reais desktop em `docs/screenshots/*019.png`. Desempenho Android ainda não medido.
