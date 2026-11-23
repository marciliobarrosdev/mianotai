CREATE OR REPLACE FUNCTION public.sync_company_selected_plan_features()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  -- Rule: every account, on every plan, always has the finance module enabled.
  NEW.financeiro_ativo := true;
  RETURN NEW;
END;
$function$;
ALTER TABLE public.company ALTER COLUMN financeiro_ativo SET DEFAULT true;
UPDATE public.company SET financeiro_ativo = true WHERE financeiro_ativo IS DISTINCT FROM true;