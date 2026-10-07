# Referências e direção do jogo

Pesquisa para a versão 0.0.17. As referências orientam nossa experiência mobile; os jogos usam regras diferentes entre versões, portanto não existe uma implementação única a copiar.

| Referência consultada | Achado | Decisão para Cidades do Brasil |
| --- | --- | --- |
| Manual oficial de SimCity (2013), seção Building a City / System Info and Data Map | Menu de construção inferior, informações do sistema e mapas por categoria | Categorias no dock, ações contextuais, mapas separados da cena normal |
| Manual oficial de Cities: Skylines, seção Bulldozer | A ferramenta demole ruas, edifícios e infraestrutura | Demolição de trechos entre junções, edifícios e instalações, com confirmação adaptada ao toque |
| Cities: Skylines II, diário Electricity & Water | A rede física e sua capacidade importam; grande parte das ruas distribui serviços, e a visão de informação destaca consumo e fontes | Componentes viários separados, capacidade local, fontes destacadas e consequências de cortar conexões |
| Citystate II, apresentação oficial no Steam | Inclui gestão de água/energia, tipos de rua e serviços públicos | Planejar catálogo coerente de serviços e progressão, sem misturar serviços futuros com botões que ainda não funcionam |
| Andy Sztark, postmortem de Citystate II | O autor discute problemas de comunicação das mecânicas, objetivos e retorno ao jogador | Mostrar causa da falta, efeito da demolição e regras de crescimento; não esconder a simulação atrás de números sem explicação |

## Entregue na 0.0.17

HUD com ícones e categorias, pausa no topo e indicadores R/C/I. Mapas de água, energia, acesso e uso do solo ocultam prédios comuns, árvores e pedestres, mantendo os lotes, as conexões e as fontes relevantes.

Bulldozer remove ruas por trecho e prédios/instalações concluídos. O jogador escolhe manter o zoneamento ou liberar terreno. Demolição modifica abastecimento, acesso, população, emprego, viagens e contas. Redes sem ligação não compartilham serviços. Confirmação pausa a simulação para estabilizar a decisão.

Estas são escolhas do nosso projeto. Não equivalem à simulação hidráulica/elétrica completa de outro jogo. A saída de moradores após demolir sua casa é uma política provisória explícita; ainda não há reassentamento.

## Ordem de desenvolvimento proposta

1. Catálogo de construção: ficha com dimensão, preço, manutenção, capacidade, requisito de acesso e impacto ambiental. Introduzir orçamento dos serviços e opções pequenas/maiores antes de multiplicar modelos.
2. Água e esgoto: fontes naturais/poços, qualidade e contaminação, bombeamento e tratamento. Água disponível e esgoto tratado precisam ser indicadores distintos.
3. Eletricidade: diferentes fontes, combustível/manutenção e capacidade de transmissão. Separar produção, distribuição e consumo; adicionar cabos próprios se o desenho de jogo justificar.
4. Ruas e evolução: hierarquia de vias, calçadas, melhorias no lugar e densidades. A troca de tipo deve preservar conexão e explicar interferências em lotes.
5. Serviços urbanos: resíduos, saúde, bombeiros, educação e segurança. Cobertura geográfica sozinha não basta; combinar capacidade e acesso, e depois atendimento por veículos/tempo de viagem.
6. Trânsito e transporte: viagens de moradores e cargas, veículos, cruzamentos e congestionamento. Expandir a população só após medir desempenho no aparelho.

Cada etapa deve incluir legenda consistente, causa/efeito na consulta do imóvel, preço e capacidade na ficha, salvamento compatível e medição no Android. Educação/saúde/esgoto/veículos ainda não foram implementados nesta versão.

## Fontes primárias

- EA, [SimCity — manual oficial (2013)](https://akamai.cdn.ea.com/eadownloads/u/f/manuals/GAME-SIMCITY/SimCity_2013.pdf).
- Paradox / Colossal Order, [Cities: Skylines — manual oficial](https://shared.steamstatic.com/store_item_assets/steam/apps/255710/manuals/CitiesSkylines-UserManual_EN.pdf).
- Paradox / Colossal Order, [Cities: Skylines II — Electricity & Water](https://www.paradoxinteractive.com/games/cities-skylines-ii/features/electricity-water).
- Andy Sztark, [Citystate II — apresentação oficial](https://store.steampowered.com/app/1352850/Citystate_II/).
- Andy Sztark, [Citystate II: Postmortem — A lesson in game design](https://www.citystategame.com/post/citystate-ii-postmortem-a-lesson-in-game-design-for-city-building-games).

## Entrega 0.0.15

Catálogo inicial de seis instalações com dimensão, capacidade, preço e manutenção, três tamanhos e previsão conservadora do orçamento. Acesso continua exigindo frente válida de rua; a distribuição respeita redes conectadas. Impacto ambiental e água/esgoto permanecem na próxima etapa. Valores são próprios do protótipo, não reproduzem números dos jogos de referência.

## Entrega 0.0.16

Captação subterrânea por áreas de vazão compartilhada, ETE em três tamanhos, coleta/tratamento por rede viária, mapa de fontes e mapa de esgoto. Regras e valores são próprios do protótipo. Preserva a cidade existente com captação e atendimento externo legados explícitos. Rios, poluição dinâmica, estoque hídrico e pressão continuam fora desta etapa.

## Entrega 0.0.17

Diagnóstico por imóvel com símbolos originais, lista filtrável, localização e ações; orçamento com realizado, operação e obras futuras. Referências de simulação permanecem as anteriores. A composição antiga de despesas não é inferida: fica explicitamente não discriminada até o primeiro fechamento após migração. Próxima etapa proposta: ruas e calçadas.
