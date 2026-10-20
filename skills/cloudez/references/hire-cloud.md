# Contratar uma cloud

Quando usar: contratar uma cloud (servidor) nova na Cloudez — o teste grátis, quando a conta ainda tem direito a ele, ou um plano pago pelo painel, já que não há tool de pagamento. Use quando o usuário pedir para contratar, comprar ou adicionar uma cloud/servidor fora do cadastro de conta.

## 0. Autenticação, antes de qualquer coisa

Feita no SKILL.md, antes de chegar aqui. Se ela passou pelo
[login.md](login.md), recomece este procedimento chamando `cloudez_auth_status`
de novo depois do login: é a resposta dela, já autenticada, que traz o
`panel_host` do passo 1.

## 1. O painel

Se a resposta do passo 0 já trouxe `panel_host`, use-o direto — **não
pergunte de novo.** É o painel da revenda da própria conta, ou o que outro
procedimento já confirmou nesta máquina.

Sem `panel_host` na resposta, pergunte o endereço que o usuário usa para
entrar na Cloudez, **em texto, não como pergunta com opções**: o endereço do
painel é texto livre, e a ferramenta de pergunta com opções de alguns agentes
recusa a chamada sem opções, e o turno se perde até cair na pergunta em texto
mesmo. Opções servem só para "qual cloud, se vier mais de uma" no passo 3. Não
presuma nenhum painel: a Cloudez é white-label, cada revenda tem o seu domínio —
`cloud.configr.com` é o da Configr, não é "o" painel.

Peça só a pergunta em si. Não mencione `panel_host` nem diga que nada foi
salvo ainda — isso é estado interno, não faz parte da pergunta.

Confirme com `cloudez_panel_info`. Se vier `panel_not_found`, o endereço
está errado — diga isso e peça de novo, em vez de seguir com um painel que
não existe. Confirmado com sucesso, o painel já fica gravado nesta máquina
sozinho — não é preciso chamar mais nada para isso.

## 2. Teste grátis, quando é isso que ele pediu

**Só entre aqui se o pedido foi por teste, trial ou cloud grátis.** Pedido sem
adjetivo ("quero contratar uma cloud") é contratação paga: siga para o passo 3
sem oferecer o teste — oferecer grátis a quem se dispôs a pagar muda o que ele
pediu.

O teste é **um por conta**, e quem decide se ainda há direito a ele é a
Cloudez, não este procedimento. Não tente adivinhar pelo que a conta já tem: uma
cloud paga não consome o trial, e uma conta sem cloud nenhuma pode já tê-lo
gasto num cloud que foi removido.

Chame `cloudez_get_trial_plan` com o `panel_host` do passo 1.

- **Sem `trial_ia_plan_id`** — esta revenda não tem plano de teste. Diga que
  aqui não existe teste grátis e siga para o passo 3, se ele quiser contratar
  pago.

Com o id, guarde os `id` que `cloudez_list_clouds()` devolve agora — é o
retrato de antes, e aqui ele serve para duas coisas: achar a cloud nova depois
e não confundir com uma que já existia. Então chame `cloudez_setup_trial_cloud`
passando o `trial_ia_plan_id` que veio.

**Não repita a chamada se ela falhar.** Não é idempotente: se o
provisionamento tiver ocorrido apesar do erro, uma segunda chamada cria uma
SEGUNDA cloud.

- **`trial_already_exists`** — a conta já usou o teste dela. Diga isso e
  ofereça a contratação paga do passo 3; não é erro, é o limite de um por
  conta;
- **`cloud_limit_reached`** — limite de clouds da conta. Não se resolve por
  aqui: diga para ele contatar o suporte da Cloudez;
- **`cloud_setup_unconfirmed`** — a chamada falhou depois de enviada, e a
  cloud pode ter sido criada mesmo assim. Chame `cloudez_list_clouds` e
  compare com o retrato de antes: apareceu uma nova, trate como sucesso; não
  apareceu, diga que o teste não pôde ser provisionado e mande para o suporte
  — **não** mande para o painel, que é contratação paga, não o teste.

Deu certo, chame `cloudez_list_clouds()` e diga qual é a cloud nova (`name`,
`fqdn`). Se o pedido original envolvia um site, ofereça seguir
[setup.md](setup.md) usando ela.

## 3. Contratar pago

Guarde os `id` que `cloudez_list_clouds()` devolve agora — é o retrato de
antes, contra o qual vai comparar depois de o usuário confirmar.

Mande:

```
Abra: https://<panel_host>/clouds/create
Contrate o plano que preferir. Quando terminar, me avise.
```

Se o passo 0 trouxe `panel_host_alt`, mostre também o link nele, logo abaixo
do primeiro: `(se não abrir, use https://<panel_host_alt>/clouds/create)`. É o
endereço `*.cloudez.app` da revenda, e há parceiro que não aponta o DNS do
domínio principal.

**Espere a confirmação dele antes de conferir.** Contratar e provisionar
levam um tempo que este procedimento não controla — não há como saber daqui
quando terminou, e não existe polling automático: quem avisa é o usuário.

Confirmado, chame `cloudez_list_clouds()` de novo e compare com o retrato de
antes:

- **Uma cloud nova** (o caso comum) — diga qual é (`name`, `fqdn`) e que está
  pronta. Se o pedido original envolvia um site, ofereça seguir
  [setup.md](setup.md) usando essa cloud;
- **Nenhuma nova ainda** — diga que a contratação pode ainda estar
  processando, e pergunte se ele quer que confira de novo. Não repita
  sozinho em loop;
- **Mais de uma nova** — pergunte qual, com as opções numeradas, mostrando
  `name` e `fqdn` de cada uma, e espere a resposta.
