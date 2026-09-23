# Manutenção via CSV (campo)

Atualização em massa pela tela, sem integração. Regras observadas em uso real; confirme o texto da tela do seu tenant.

## 1. Onde
- Clientes: **Configurações > Clientes > Manutenção via CSV**, ação **Atualização**.
- Contatos: tela equivalente de manutenção de contatos.
- Formato: **CSV ou TSV**.

## 2. Identificação
| Tabela | Chave obrigatória |
|---|---|
| Clientes | ID Original (`id_legacy`) **ou** ID Sensedata |
| Contatos | Cliente (ID Original ou ID Sensedata) **e** Telefone 1/Telefone 2 e/ou E-mail |

- Em contatos, a manutenção casa por **(cliente, e-mail)** (ou telefone), **não** pelo ID do contato. Se a mesma conta tem dois contatos com o mesmo e-mail, a dupla é ambígua.
- Não se sabe, sem testar, se a comparação de e-mail respeita maiúsculas/minúsculas. Use a caixa exata do registro que você quer atingir e teste.

## 3. O que é gravado
- **Só as colunas presentes no arquivo.** O que não está no arquivo não é tocado. Mande a chave e só o que muda: é a forma segura de não apagar nada.
- Campos customizados: a tela avisa que "somente serão atualizados se forem do tipo data, número ou texto". Listas (seleção, usuários) podem **não** ser gravadas: teste com uma linha; se não gravar, use a API.
- Os cabeçalhos precisam bater com o que a tela espera (nome do campo ou rótulo, conforme o tenant). Exports da tela podem ter colunas de nome quase igual (ex.: com espaço no fim); não renomeie sem conferir.

## 4. Procedimento seguro
1. **Pause** qualquer carga ou rotina que escreva nos mesmos campos (senão ela desfaz a manutenção).
2. Exporte o estado atual dos registros-alvo (rollback).
3. Monte o arquivo mínimo (chave + colunas que mudam).
4. **Piloto** com poucas linhas; confira na Visão 360.
5. Suba o resto em lotes; confira contagens depois de cada lote.
6. Religue as cargas só depois de corrigir a causa que exigiu a manutenção.

## 5. Reativar contatos inativados por engano
- Alvo: pessoas-conta que ficaram sem nenhum contato ativo e que deveriam estar ativas.
- Exclua quem já tem outro contato ativo na mesma conta (mesmo criado à mão), senão a pessoa fica com dois ativos.
- Escolha, por pessoa-conta, o registro que preserva o dado manual (ex.: marcação preenchida), depois o que tem produto, depois o mais recente.
- **Lote A**: (cliente, e-mail) acha um contato só → sobe primeiro, sem risco de ambiguidade.
- **Lote B**: (cliente, e-mail) acha mais de um → piloto; se a manutenção ativar todos os que casam, trate de outro jeito (API por ID do contato).
- Depois: nenhuma pessoa do alvo sem contato ativo; dados manuais no registro ativo (se estiverem presos no inativo, migre o campo).
Queries de apoio: skill sense-connect, `references/sql-base-espelho.md`, seção 8.

## 6. Carga inicial de um campo a partir de export
Para preencher um campo pela primeira vez sem API:
1. Exporte Tabelas > Clientes (e, se precisar, Configurações > Usuários).
2. Calcule o valor de cada cliente fora (planilha ou script), registrando pendências.
3. Monte o CSV `ID Original | <campo>`.
4. Suba com a ação Atualização (piloto primeiro).
Se o campo for lista de usuários e a manutenção não gravar, a carga precisa ir pela API.
