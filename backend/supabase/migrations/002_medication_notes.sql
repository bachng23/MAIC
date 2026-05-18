-- Add optional user-entered notes (e.g. OCR context, pharmacist instructions).
-- Run in Supabase SQL Editor if the database was created from an older migration.sql.

alter table public.medications
  add column if not exists notes text;
