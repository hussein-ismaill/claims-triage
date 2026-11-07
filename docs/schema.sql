-- Supabase / Postgres schema for the claims triage prototype.
-- Paste into the Supabase SQL editor (or move into supabase/migrations once Lovable is connected).

-- Policy versions: rules live as JSON config (same shape as /policies/*.json)
create table if not exists policy_versions (
  id            text primary key,              -- 'v1', 'v2'
  config        jsonb not null,
  description   text,
  status        text not null default 'draft', -- draft | approved | active | retired
  created_by    text,
  approved_by   text,                          -- the claims policy owner
  approved_at   timestamptz,
  created_at    timestamptz not null default now()
);

-- Claims exactly as received. Blank fields stay NULL (absent fact, never defaulted).
create table if not exists claims (
  case_id                    text primary key,
  case_status                text,             -- open | closed | NULL
  claim_summary              text,
  policy_active_on_incident  boolean,
  claim_type                 text,
  repair_type                text,
  quote_eur                  numeric,
  incident_report_present    boolean,
  itemized_quote_present     boolean,
  injury_reported            boolean,
  liability_disputed         boolean,
  duplicate_flag             boolean,
  evidence_conflict          boolean,
  raw                        jsonb,            -- original row / claim pack, kept as evidence
  received_at                timestamptz not null default now()
);

-- Every engine run produces an immutable decision row tied to a policy version.
create table if not exists decisions (
  id               bigint generated always as identity primary key,
  case_id          text not null references claims(case_id),
  policy_version   text not null references policy_versions(id),
  recommendation   text not null check (recommendation in ('routine_processing','request_information','human_review')),
  rule_id          text not null,              -- e.g. 'v1.R1'
  explanation      text not null,
  missing_fields   text[] default '{}',        -- absent facts, shown as uncertainty in the UI
  needs_recheck    boolean not null default false,
  is_current       boolean not null default true,
  created_at       timestamptz not null default now()
);
create index if not exists decisions_case_idx on decisions(case_id, created_at desc);

-- Reviewer overrides: append-only audit trail (judges test one live override).
create table if not exists overrides (
  id                       bigint generated always as identity primary key,
  decision_id              bigint not null references decisions(id),
  case_id                  text not null references claims(case_id),
  policy_version           text not null references policy_versions(id),
  original_recommendation  text not null,
  new_recommendation       text not null check (new_recommendation in ('routine_processing','request_information','human_review')),
  reason_code              text,              -- e.g. 'evidence_misread', 'policy_gap', 'new_information'
  reason_text              text not null,
  reviewer                 text not null,
  created_at               timestamptz not null default now()
);

-- True outcomes arrive weeks later; linked to the decision, never overwriting it.
create table if not exists outcomes (
  id              bigint generated always as identity primary key,
  case_id         text not null references claims(case_id),
  decision_id     bigint references decisions(id),
  final_outcome   text not null,              -- e.g. 'paid_routine', 'fraud_found', 'coverage_denied', 'info_received'
  correct_next_step text,                     -- what the next step should have been, in hindsight
  recorded_by     text,
  recorded_at     timestamptz not null default now()
);

-- Make the audit tables append-only (no updates/deletes from the app).
revoke update, delete on overrides from anon, authenticated;
revoke update, delete on outcomes from anon, authenticated;
