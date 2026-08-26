DO $$
DECLARE
  v_owner uuid;
  v_tg    bigint;
BEGIN
  v_tg := current_setting('lni.owner_telegram_user_id')::bigint;
  IF v_tg IS NULL OR v_tg <= 0 THEN
    RAISE EXCEPTION 'lni.owner_telegram_user_id is missing or invalid';
  END IF;

  SELECT owner_id INTO v_owner
  FROM public.events WHERE name = 'LEAP 2026';

  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'LEAP 2026 event row not found or has no owner_id';
  END IF;

  INSERT INTO public.bot_state (owner_id, telegram_user_id, mode)
  VALUES (v_owner, v_tg, 'normal')
  ON CONFLICT (owner_id, telegram_user_id) DO NOTHING;

  IF NOT EXISTS (
    SELECT 1 FROM public.bot_state
    WHERE owner_id = v_owner AND telegram_user_id = v_tg
  ) THEN
    RAISE EXCEPTION 'bot_state seed did not result in a row';
  END IF;
END $$;
