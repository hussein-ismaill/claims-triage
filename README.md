# Trustworthy claims triage

Taktile case, thinc! Munich hackathon, 7–8 November 2026.

The prototype reads a fictional motor claim and recommends **routine_processing**, **request_information** or **human_review**. It shows the facts and the policy rule behind each recommendation, records reviewer overrides, and handles policy changes with versioning: open cases are rechecked, closed cases stay frozen.

## Batch run (judging path)

Requires Python 3.9+. No external dependencies.

```bash
python engine/triage.py path/to/claims.csv output/results.csv
```

Output columns: `case_id, recommendation_v1, recommendation_v2, needs_recheck, rule_v1, rule_v2, explanation`.
For closed claims, `recommendation_v2` repeats the v1 decision and `needs_recheck` is `False`.

Optional: `--v1 policies/v1.json --v2 policies/v2.json` to choose the policy files.

## Tests and quality report

```bash
python tests/test_engine.py          # regression tests
python engine/report.py data/dev_cases.csv   # accuracy, wrong-routine rate, unnecessary-escalation rate, changed cases
```

## Repo layout

```
engine/triage.py      rules engine + batch CLI (config-driven)
engine/report.py      quality report per policy version
policies/v1.json      policy v1 as config
policies/v2.json      policy v2 (filled in at the 18:00 change)
data/                 labelled dev cases (14) and unlabelled practice cases (12)
tests/                regression tests
docs/POLICY.md        policy reference and v2 notes
docs/PLAN.md          roles, timeline, demo script
docs/BUSINESS_CASE.md business case assumptions and outputs
docs/schema.sql       Supabase schema (claims, decisions, overrides, outcomes, policy versions)
```

## Design principles

- Structured fields decide the outcome. A language model may extract facts or draft explanations, but it never overrides the written policy.
- Blank fields are absent facts. They are never guessed.
- Every recommendation carries its policy version and rule ID.
- Overrides and real outcomes are recorded append-only, linked to the decision they correct.
