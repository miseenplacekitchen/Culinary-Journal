-- garden-v4-04-import-queue.sql — staging for Variety Assessment docx ingestion

CREATE TABLE IF NOT EXISTS public.garden_import_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_path text NOT NULL,
  species_name text,
  species_slug text,
  climate_slug text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','parsed','staging','approved','failed')),
  variety_count integer NOT NULL DEFAULT 0,
  payload jsonb,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz
);

CREATE INDEX IF NOT EXISTS garden_import_queue_status_idx ON public.garden_import_queue (status, created_at DESC);

SELECT 'garden-v4-04-import-queue ready' AS status;
