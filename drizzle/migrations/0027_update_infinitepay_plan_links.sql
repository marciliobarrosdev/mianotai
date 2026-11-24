SELECT set_config('app.plan_admin_write','on',true);
UPDATE public.plan SET checkout_url='https://checkout.infinitepay.io/marcilio-daniel-5z4/nzCPaVY6R3', checkout_mode='external', preco_cents=1490 WHERE slug='starter';
UPDATE public.plan SET checkout_url='https://checkout.infinitepay.io/marcilio-daniel-5z4/6zceq56ddZ', checkout_mode='external', preco_cents=2500 WHERE slug='pro';
UPDATE public.plan SET trial_days=7, creditos_trial=30, preco_cents=0 WHERE slug='free';