CREATE OR REPLACE FUNCTION public.create_checkout_company_atomic(_user_id uuid, _company_name text, _plan_slug text, _slug_base text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  _company_id uuid;
  _plan_id uuid;
  _resolved_plan_slug text;
  _requested_plan_slug text;
  _trial_days integer;
  _trial_end timestamptz;
  _candidate_slug text;
  _suffix integer := 0;
  _paid boolean;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Checkout disponível somente para o runtime seguro';
  END IF;
  IF NOT public.is_remix_installation_claimed() THEN
    RAISE EXCEPTION 'O clone precisa ser ativado antes de criar empresas';
  END IF;
  IF _user_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth.users AS u WHERE u.id = _user_id AND u.email_confirmed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'Conta confirmada obrigatória';
  END IF;
  IF char_length(trim(COALESCE(_company_name, ''))) < 2 THEN
    RAISE EXCEPTION 'Nome da empresa inválido';
  END IF;
  IF COALESCE(_slug_base, '') !~ '^[a-z0-9]+(-[a-z0-9]+)*$'
     OR char_length(_slug_base) > 48 THEN
    RAISE EXCEPTION 'Slug base inválido';
  END IF;
  -- Plano é obrigatório: nenhuma assinatura nasce com plano presumido.
  _requested_plan_slug := NULLIF(lower(trim(COALESCE(_plan_slug, ''))), '');
  IF _requested_plan_slug IS NULL THEN
    RAISE EXCEPTION 'Escolha um plano para começar';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('marcia:checkout:' || _user_id::text, 0)
  );
  SELECT cu.company_id INTO _company_id
  FROM public.company_user AS cu
  WHERE cu.user_id = _user_id AND cu.ativo = true
  ORDER BY cu.created_at ASC
  LIMIT 1;
  IF _company_id IS NOT NULL THEN
    RETURN _company_id;
  END IF;
  SELECT p.id, p.slug, greatest(0, p.trial_days), (NOT COALESCE(p.is_free,false) AND p.preco_cents > 0)
    INTO _plan_id, _resolved_plan_slug, _trial_days, _paid
  FROM public.plan AS p
  WHERE p.slug = _requested_plan_slug AND p.ativo = true;
  IF _plan_id IS NULL THEN
    RAISE EXCEPTION 'Plano selecionado não está disponível';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('marcia:company-slug:v1', 0)
  );
  _candidate_slug := left(_slug_base, 39) || '-' || left(replace(_user_id::text, '-', ''), 8);
  WHILE EXISTS (SELECT 1 FROM public.company WHERE slug = _candidate_slug) LOOP
    _suffix := _suffix + 1;
    _candidate_slug := left(_slug_base, 34) || '-' || left(replace(_user_id::text, '-', ''), 8) || '-' || _suffix::text;
    IF _suffix > 9999 THEN
      RAISE EXCEPTION 'Não foi possível gerar um slug único para a empresa';
    END IF;
  END LOOP;
  _trial_end := pg_catalog.now() + pg_catalog.make_interval(days => _trial_days);
  -- Plano pago sem teste: nasce aguardando pagamento (o webhook libera).
  INSERT INTO public.company (
    nome, nome_fantasia, slug, primary_color, created_by, status_cobranca,
    onboarding_completed, onboarding_step, trial_ate, selected_plan_slug
  ) VALUES (
    left(trim(_company_name), 120), left(trim(_company_name), 120), _candidate_slug, '#25D366', _user_id,
    CASE WHEN _paid AND _trial_days = 0 THEN 'checkout_pending' ELSE 'trial' END,
    false, 0, _trial_end, _resolved_plan_slug
  )
  RETURNING id INTO _company_id;
  INSERT INTO public.company_user (user_id, company_id, role, ativo)
  VALUES (_user_id, _company_id, 'owner'::public.tenant_role, true);
  INSERT INTO public.subscription (
    company_id, plan_id, status, trial_ends_at, current_period_start, current_period_end, metadata
  ) VALUES (
    _company_id, _plan_id,
    CASE WHEN _paid AND _trial_days = 0 THEN 'incomplete' ELSE 'trialing' END,
    _trial_end, pg_catalog.now(), _trial_end,
    jsonb_build_object('source', CASE WHEN _paid AND _trial_days = 0 THEN 'self_service_checkout' ELSE 'self_service_trial' END)
  );
  RETURN _company_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.enforce_company_operational_write()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  _company_id uuid;
  _previous_company_id uuid;
  _new_row jsonb;
  _old_row jsonb;
BEGIN
  _company_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.company_id ELSE NEW.company_id END;
  _previous_company_id := CASE WHEN TG_OP = 'UPDATE' THEN OLD.company_id ELSE _company_id END;
  IF TG_OP = 'DELETE' AND COALESCE(auth.role(), '') = 'service_role' THEN
    RETURN OLD;
  END IF;
  IF TG_TABLE_NAME = 'company_user' AND COALESCE(auth.role(), '') = 'service_role' THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;
  -- Trusted signup setup (seed_default_stages) runs before payment confirmation.
  IF TG_OP = 'INSERT' AND TG_TABLE_NAME = 'crm_stage' AND COALESCE(auth.role(), '') = 'service_role' THEN
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' AND TG_TABLE_NAME IN ('webhook_endpoint', 'api_token') THEN
    _new_row := pg_catalog.to_jsonb(NEW);
    _old_row := pg_catalog.to_jsonb(OLD);
    IF (_new_row ->> 'company_id') = (_old_row ->> 'company_id')
       AND (
         (TG_TABLE_NAME = 'webhook_endpoint'
           AND (_old_row ->> 'ativo') = 'true' AND (_new_row ->> 'ativo') = 'false'
           AND (_new_row - 'ativo' - 'updated_at') = (_old_row - 'ativo' - 'updated_at'))
         OR (TG_TABLE_NAME = 'api_token'
           AND (_old_row ->> 'revogado') = 'false' AND (_new_row ->> 'revogado') = 'true'
           AND (_new_row - 'revogado' - 'updated_at') = (_old_row - 'revogado' - 'updated_at'))
       ) THEN
      RETURN NEW;
    END IF;
  END IF;
  IF NOT public.is_super_admin()
     AND (NOT public.is_company_operational(_company_id) OR NOT public.is_company_operational(_previous_company_id)) THEN
    RAISE EXCEPTION 'A operação desta empresa está bloqueada. Regularize o plano para continuar.'
      USING ERRCODE = '42501';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$function$;