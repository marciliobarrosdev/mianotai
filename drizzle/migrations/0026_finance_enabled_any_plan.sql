CREATE OR REPLACE FUNCTION public.company_finance_enabled(_company_id uuid)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $$
  -- Rule: finance is enabled for every account on every plan.
  SELECT EXISTS (SELECT 1 FROM public.company AS company WHERE company.id = _company_id);
$$;

CREATE OR REPLACE FUNCTION public.fin_enable_for_company(_company_id uuid, _enable boolean)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR COALESCE(auth.role(), '') <> 'authenticated' THEN
    RAISE EXCEPTION 'Autenticação obrigatória' USING ERRCODE = '42501';
  END IF;
  IF _company_id IS NULL THEN
    RAISE EXCEPTION 'Empresa é obrigatória';
  END IF;
  IF NOT (public.is_super_admin() OR public.has_company_role(_company_id, ARRAY['owner','admin'])) THEN
    RAISE EXCEPTION 'Acesso negado' USING ERRCODE = '42501';
  END IF;
  -- Finance can never be turned off; always enable and seed.
  UPDATE public.company SET financeiro_ativo = true WHERE id = _company_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empresa não encontrada';
  END IF;
  PERFORM public.seed_fin_categorias(_company_id);
END;
$$;