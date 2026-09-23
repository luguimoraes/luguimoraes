# Campos customizados

## 1. Onde e como (guia)
Configurações > Clientes > **Campo customizado** > **Novo campo**:
- **Título do campo** (exibição)
- **Identidade do campo**
- **Origem** do preenchimento
- **Tipo do campo**
- **Máscara** (opcional)
- **Condição**
- **Salvar**

## 2. Convenções (campo)
- **Nome interno**: minúsculas, sem acento, `_` entre palavras (`dt_ultima_anotacao_cs`). Gere com `scripts/nome_interno.py`.
- **Colisão**: se já existir um campo com o mesmo nome, a plataforma pode sufixar (`cs_feeling` → `cs_feeling_2`). Depois de criar, **confira o nome interno real** e use-o em rotinas, integrações, SQL e documentação. Nome errado não dá erro: grava em lugar nenhum.
- **Prefixos úteis**: `dt_` para datas, `qtd_`/`dias_` para contagens, `flag_` para sim/não, `nivel_` para listas lidas por regra.
- **Um campo por conceito**. Não reaproveite campo com outro significado (ex.: produto guardado no campo "Skype"): quebra filtros, relatórios e chaves de integração.
- **Dono do campo** explícito: pessoa, regra, integração ou rotina. Derivados ficam **não editáveis**.

## 3. Tipos e cuidados
| Tipo | Uso | Cuidado |
|---|---|---|
| Texto | Nomes, códigos, anotações curtas | Regra compara com diferença de maiúsculas; tamanho máximo pode existir |
| Número inteiro | Contagens, dias | Nunca `NULL` para "não se aplica" se a tabela é ordenada por ele; use um marco (ex.: data de início do contrato) |
| Data | Marcos | Operações "Há 'X' ou menos dias" / "Em 'X' ou menos dias"; confira fuso se vier de integração |
| Lista de seleção única | Estados, níveis, faixas | Poucos valores; grafia exata; na base espelho, o valor pode ser texto ou objeto |
| Lista de seleção múltipla | Marcações (ex.: produtos de referência) | Na base espelho é **array jsonb** (`["A","B"]`); filtros de texto enganam |
| Lista de usuários | Remetente dinâmico, responsável secundário | Aceita só **usuário** da plataforma; a Manutenção via CSV pode não gravar; teste o formato na API (e-mail, nome ou id) |

## 4. Especificação modelo
Use esta tabela para cada campo novo:
| Propriedade | Valor |
|---|---|
| Exibição | `Nível de alerta de inatividade` |
| Nome interno | `nivel_alerta_inatividade` (confirmar após criar) |
| Tabela | Cliente |
| Tipo | Lista de seleção única |
| Opções | `nenhum`, `alerta_90`, `escalonamento_105`, `critico_120` |
| Editável na tela | Não |
| Obrigatório | Não |
| Preenchido por | Rotina diária (API), 06:00 |
| Lido por | Regras "[CS Ops] Inatividade 90d/105d/120d" |
| Vazio significa | Rotina não rodou para o cliente → regra não dispara |

## 5. Exemplos de conjuntos de campos

### 5.1 Régua de inatividade do CS
| Exibição | Nome interno | Tipo | Editável | Preenchido por |
|---|---|---|---|---|
| CS Feeling | `cs_feeling` | Lista (Verde, Amarelo, Vermelho) | Sim | CS |
| Data última atualização do CS Feeling | `dt_ultima_atualizacao_cs_feeling` | Data | Não | Rotina: data da última **mudança** de valor (reabrir e salvar sem mudar não conta) |
| Data da última anotação do CS | `dt_ultima_anotacao_cs` | Data | Não | Rotina: última anotação de **usuário do time de CS** (anotações automáticas não contam) |
| Dias sem atualização do CS | `dias_sem_atualizacao_cs` | Inteiro | Não | Rotina: `MIN(dias desde anotação, dias desde feeling)` |
| Nível de alerta de inatividade | `nivel_alerta_inatividade` | Lista | Não | Rotina (seção 1.1 de `regras-avancadas.md`) |
| E-mail do líder de CS | `email_lider_cs` | Texto | Não | Integração de estrutura do time |

Notas:
- `cs_feeling` com 3 opções, não 5: escala subjetiva de 5 pontos concentra no meio e não é reproduzível entre pessoas.
- Não obrigatório: a régua já é o mecanismo de cobrança.
- Se as anotações automáticas contarem, o contador nunca chega a 90 e a régua morre em silêncio (tela toda verde).
- A API costuma expor só o valor **atual** de um campo, não o histórico: a data de mudança do feeling precisa ser reconstruída por snapshot diário (a primeira leitura é **baseline**, não "atualizado hoje", senão o contador de toda a base zera no go-live).

### 5.2 Conta matriz / grupo econômico
| Exibição | Nome interno | Tipo | Onde |
|---|---|---|---|
| Tipo de conta | `tipo_conta` | Lista (`matriz`, `loja`…) | Todas as contas |
| CS Feeling do grupo | `cs_feeling_grupo` | Texto/Lista | Lojas (integração) |
| Anotações do grupo | `anotacoes_grupo` | Texto | Matriz (CS) e lojas (integração) |
| Conta matriz | `conta_matriz_nome` | Texto | Lojas (integração) |
| Grupo atualizado em | `grupo_atualizado_em` | Texto `DD/MM/AAAA HH:MM` ou Data | Lojas (integração) |

### 5.3 Remetente dinâmico
| Exibição | Nome interno | Tipo | Preenchido por |
|---|---|---|---|
| Comercial da Conta | `comercial_da_conta` | Lista de usuários | Rotina que resolve o nome do comercial (texto) para o usuário |

## 6. Como o campo aparece em cada lugar
| Lugar | Como referenciar |
|---|---|
| Regras (condição e ação Atualização) | Pelo título, dentro da categoria da tabela (Cliente, Contato) |
| Templates de e-mail | "Mesclar Marcadores" > Campos customizados |
| Visão 360 / tabelas | Coluna com o título; export da tela usa o título (atenção a títulos parecidos com campos nativos) |
| API v2 | Nome interno (`custom_fields`) |
| SenseConnect (mapeamento) | Nome interno em "Coluna na Sensedata" |
| Base espelho (SQL) | `custom_fields -> '<nome_interno>' ->> 'value'` |
