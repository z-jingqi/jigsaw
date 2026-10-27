# Completion subject introduction: sources

Reviewed 2026-10-26. Scope follows the latest user instruction: only the nine-tailed fox is populated. Other levels intentionally have no entry; do not substitute their existing scene descriptions.

## `shanhai_v2_01` — 九尾狐 / Nine-tailed fox

- Primary text: **《山海经·南山经》**, 青丘之山 passage.
- Consulted digital transcription: [Wikisource: 山海經/南山經](https://zh.wikisource.org/zh-hans/山海經/南山經).
- Verified points: Qingqiu; fox-like form with nine tails; cry compared to an infant's voice.
- Editorial distinction: the entry explicitly presents an ancient Chinese mythological creature, not a real fox breed. No claim is made that the artwork depicts a real place or event.
- The Chinese, English, and Japanese introductions convey the same facts. Text is an original short summary, not a description of the illustration.

## Data contract and checks

`levels/subject_intros.json` stores `levels[level_id].subject_intro_i18n`, with `zh`, `en`, and `ja` values. The UI normalizes `zh-Hans` to `zh`.

Verified: one unique level ID matching the catalog; three nonempty locale values; no placeholder entries; original level files and descriptions unchanged by this content task. Runtime/UI testing belongs to the integrating UI task; repository suites are paused per `AGENTS.md` and were not run here.
