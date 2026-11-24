# Cadastro pelos Planos + pagamento InfinitePay + liberação automática

## O que o assinante vai viver
1. **Gratuito:** escolhe o plano, preenche o cadastro e vai direto para o login/app. Recebe 7 dias e 30 créditos de IA, sem WhatsApp. Só pode usar uma vez por conta. Ao vencer o prazo ou acabarem os créditos, o app pede upgrade para Basic ou PRO.
2. **Basic (R$ 14,90/mês) ou PRO (R$ 25,00/mês):** escolhe o plano, preenche o cadastro e é levado na hora para a página de pagamento da InfinitePay daquele plano, já com o e-mail preenchido. Enquanto o pagamento não é confirmado, fica numa tela "Aguardando pagamento", que se atualiza sozinha.
3. **Pagamento aprovado:** a InfinitePay avisa o sistema. A conta é ativada no plano pago, recebe os créditos do mês e o WhatsApp é liberado. A tela de espera libera o acesso automaticamente.

## Correções
- **Planos salvos:** atualizar Basic e PRO com os novos preços e links. Configurar o Gratuito com 7 dias, 30 créditos, WhatsApp bloqueado e sem renovação. As alterações passam pelo caminho oficial de edição de planos, que fica registrado no histórico.
- **Fluxo de cadastro:** hoje, depois do cadastro, a tela de checkout inicia um teste automático para qualquer plano. Vou mudar para: plano gratuito ativa o teste, plano pago cria a conta como "aguardando pagamento" e redireciona para o link da InfinitePay.
- **Confirmação do pagamento:** o aviso da InfinitePay identifica o plano pelo valor pago (R$ 14,90 = Basic, R$ 25,00 = PRO) e o assinante pelo e-mail do comprador. Antes de ativar, o sistema confere o pagamento direto na InfinitePay. Vou incluir também o código da conta no link de pagamento para encontrar o assinante mesmo que ele pague com outro e-mail.
- **Bloqueios do Gratuito:** confirmar no servidor que o WhatsApp fica bloqueado no Gratuito e que, ao fim dos 7 dias ou dos 30 créditos, o acesso passa a mostrar a tela de upgrade.
- **Chave da InfinitePay:** salvar a chave e o handle `$marcilio-daniel-5z4` criptografados nas integrações do Master. A chave nunca fica no código nem aparece no navegador. Recomendo gerar uma chave nova na InfinitePay depois, porque esta foi enviada pelo chat.

## Verificação
- Testes automáticos para: valor pago → plano correto, Gratuito usado só uma vez, conta aguardando pagamento até a confirmação, e WhatsApp bloqueado no Gratuito.
- Teste no navegador: cadastro no Gratuito leva ao app; cadastro no Basic/PRO leva ao link certo da InfinitePay.
- Simulação de um aviso de pagamento aprovado para confirmar que o assinante é ativado no plano certo. Um pagamento real só pode ser confirmado por você, depois de publicar.

## Detalhes técnicos
- `src/routes/app/checkout.tsx`: só chamar `iniciarTrial()` quando `price_cents = 0`; para plano pago, usar `checkoutLinkForPlan` com `email` e referência da empresa e redirecionar com `window.location.assign`.
- Regras em `plan-transition-rules.ts` (precisa de pagamento / gratuito), com testes em `tests/`.
- Webhook `/api/public/billing/infinitepay`: manter `payment_check`; resolver a empresa primeiro pela referência (`order_nsu`) e depois pelo e-mail; chamar `applyEvent` (que já é idempotente).
- Planos atualizados via `master_save_plan`, com preços únicos entre os planos ativos.
- Credenciais gravadas por `resolveIntegration`/`platform_integration_secret`.
- Atualizar a memória de preços (Basic R$ 14,90 / PRO R$ 25,00) e a documentação (README, MANUAL, NOVAS-IMPLEMENTAÇÕES).
