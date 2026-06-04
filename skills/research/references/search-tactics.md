# Search tactics & source evaluation

Reference for the `/research` skill. Read this before searching; subagents should load it once at the start of their thread.

## Crafting queries

The query is the lever. Most weak research is weak queries, not weak tools.

- **One concept per query.** Don't cram a whole question into one search. Split "best vector DB for low-latency RAG in 2026" into separate searches for *latency benchmarks*, *RAG suitability*, *2026 releases*.
- **Use keywords, not prose questions.** Search engines rank on terms. `postgres logical replication throughput limits` beats `what are the limits of how much postgres logical replication can handle`.
- **Add the discriminators that matter**: year/recency (`2026`, `latest`), entity names, version numbers, units, jurisdiction. Specificity raises precision.
- **Match the vocabulary of the source you want.** Use the field's terms of art (academic, legal, engineering) — that's what authoritative pages use.
- **Run query variants in parallel.** Issue several angles at once rather than one query, reading, re-querying. Diversity of phrasing surfaces diversity of sources.

## Iterating

- If results are **too broad**, add constraints (a qualifier, a year, a site/domain, a specific subtopic).
- If **too narrow / empty**, drop the rarest term, generalize the phrasing, or try a synonym.
- Mine good results for **better search terms** — the exact phrase an authoritative page uses, then search that phrase.
- **Go to the primary source.** When a secondary article references a study, report, spec, filing, or dataset, search for and fetch *that* original, not the commentary about it.
- **Stop when you saturate.** When new searches keep returning sources you've already seen and no new claims, the thread is done — don't pad it.

## Search depth & parameters

If the search tool exposes them (e.g. Tavily), use them deliberately:

- **Depth**: use a deeper/advanced search for hard, contested, or niche questions; a basic search for simple lookups (cheaper, faster).
- **`max_results`**: raise it for landscape/survey questions, keep it low for targeted facts.
- **Domain include/exclude**: include known-authoritative domains (official docs, standards bodies, primary outlets); exclude content farms when they pollute results.
- **Time range**: constrain to recent windows for fast-moving topics; widen for historical or foundational questions.
- **Extract over snippet**: when a tool offers content extraction, fetch the page body — snippets are lossy and sometimes misleading.

## Judging source quality

Rank what you cite. Higher tiers override lower ones on conflict.

1. **Primary / official** — the actual paper, spec, standard, filing, dataset, repo, or first-party docs/announcement. Strongest.
2. **Reputable secondary** — established outlets, recognized domain experts, peer-reviewed reviews. Good, but check what they're citing.
3. **Community** — forums, Q&A, blogs, social. Useful for leads and lived experience; corroborate before relying.
4. **Anonymous / SEO / AI-spun** — unattributed listicles, content farms. Treat as a pointer at best, never a citation.

Always check: **who** published it, **when** (is it current / superseded?), **what they cite**, and whether they have an **incentive** that colors the claim. For any load-bearing fact, corroborate with a **second, independent** source — not a republish of the first.

## Red flags

- A claim that appears everywhere but always traces back to one origin → still single-source.
- No date, or a date that predates the thing being discussed.
- Confident numbers with no methodology or citation.
- Marketing pages describing their own product's superiority — cite for *claims made*, not for *facts established*.
