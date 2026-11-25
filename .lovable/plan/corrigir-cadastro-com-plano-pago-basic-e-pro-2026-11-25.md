# Corrigir cadastro com plano pago (Basic e PRO)

## Causa encontrada
Ao escolher Basic ou PRO, o sistema cria a conta com "0 dias de teste". No mesmo instante, o banco tenta preparar as etapas padrão da conta (funil inicial), mas a regra de proteção entende que essa conta já está "vencida" e bloqueia tudo. Resultado: a conta não é criada, aparece "A operação desta empresa está bloqueada…" e a pessoa nunca chega à InfinitePay. Confirmado: os dois cadastros de teste mais recentes ficaram sem conta.

## O que vou mudar
1. **Conta paga nasce "aguardando pagamento"**: Basic/PRO sem teste grátis passam a ser criados com status de pagamento pendente (não como teste vencido). Plano Gratuito e planos com dias de teste continuam iguais.
2. **Preparação inicial liberada só para o sistema**: a criação das etapas padrão da conta, feita pelo próprio sistema no cadastro, deixa de ser barrada. Qualquer uso pelo assinante continua bloqueado até o pagamento.
3. **Fluxo completo**: cadastro → conta aguardando pagamento → abre o checkout InfinitePay do plano → aviso de pagamento (webhook) confirma com a InfinitePay → plano liberado e a tela de espera leva o assinante ao app.
4. **Revisar o aviso de pagamento** para garantir que ele ativa uma conta "aguardando pagamento" (não só contas em teste) e cria a assinatura correta.
5. Testes automáticos para: conta paga nasce pendente; pendente exige pagamento; pagamento de R$ 14,90 ativa Basic e R$ 25,00 ativa PRO.

## Verificação
- Cadastro real de teste no navegador com Basic, confirmando a abertura do checkout InfinitePay.
- Simulação do aviso de pagamento confirmando a liberação do plano.
- Não consigo pagar de verdade aqui; o pagamento real fica para você testar após publicar.

## Detalhes técnicos
- Migração: `create_checkout_company_atomic` usa `status_cobranca = 'checkout_pending'` e assinatura `incomplete` quando `trial_days = 0` e o plano é pago.
- `enforce_company_operational_write`: permitir `INSERT` em `crm_stage` quando `auth.role() = 'service_role'` (seed do trigger `seed_default_stages`).
- Conferir `applyEvent` / webhook InfinitePay para transição `checkout_pending → ativo`.
