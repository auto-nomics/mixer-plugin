# mixer plugin

Migrated from the legacy `mixer_container` wrapper in nodes-io. One
directory = one plugin family = one git-able unit. The family holds TWO
node kinds that share one image and one signed-LD panel:

- `mixer_fit1` — univariate fit: one sumstats input, emits the official
  fit JSON + log.
- `mixer_fit2` — bivariate fit: four inputs (trait1 sumstats, trait2
  sumstats, trait1 fit1 JSON, trait2 fit1 JSON, in that order), emits
  the official bivariate JSON + log.

## Layout

- `manifest.toml` — node kinds `mixer_fit1` / `mixer_fit2`: params,
  ports, panel binding, image provenance
- `scripts/fit1.sh`, `scripts/fit2.sh` — execution scripts, referenced
  relatively and inlined by the loader at startup
- `Dockerfile` — image provenance; build context is the vendored
  `gsa-mixer/` checkout (`test_mixer_fit1.sh` builds and smoke-tests it)
- `gsa-mixer/` — vendored upstream source (plain files, no embedded
  `.git`), the Docker build context
- `mixer/` — vendored `precimed/mixer` companion repo (figures/usecases),
  not consumed by the Dockerfile; kept for reference
- `test_mixer_fit1.sh` — image baseline: builds/pulls, verifies the
  digest matches the manifest, smoke-tests `--version` and `fit1 --help`,
  and asserts the image carries no reference data

The chr21-22 migration fixtures (panel staging inputs and the fit
baselines) remain in the main repository at
`containers/mixer/fixtures/mixer-test-data/` because a live (ignored)
Rust integration test (`nodes-io/tests/container_file_flow.rs`) still
resolves them there via `AUTONOMICS_MIXER_IT_SOURCE`.

## Install

```sh
export AUTONOMICS_PLUGIN_ROOT=/mnt/projects/node-plugins
cargo test -p container-plugin --test mixer_migration   # golden parity
```

## Migration parity

The golden test (`container-plugin/tests/mixer_migration.rs`) compares
each compiled `ContainerCommandSpec` against the legacy Rust wrapper's
`container_spec`: image, panel bundle, outputs, resources
(2.0 CPUs / 16Gi / pids 512), timeout (21600s), artifact prefix
(`/artifacts/mixer_container`), and env are equal. Notes:

- The legacy `MixerContainerSpec.artifact_prefix` / `timeout_secs` spec
  params became fixed node-level manifest fields (the ldsc pilot's
  convention); agents can no longer tune them per DAG node.
- The legacy Rust-side validation of `seed` (0..2147483647) and the
  `> 0` bounds on `diffevo_fast_repeats`, `kmax_pdf`,
  `downsample_factor`, and `threads` are expressed as param `min` /
  `max` / `exclusive_min` bounds.
- `chr2use` has no string-pattern constraint in the v0 param DSL, so
  the scripts add a cheap fail-closed format guard and mixer.py performs
  the full range validation at run time.
- Scripts are semantic, not byte-exact: the legacy wrapper built argv in
  Rust (`command_prefix`), the plugin drives the same official flags
  through `MIXER_*` env vars. Both `--out "$out_prefix"` (with
  `out_prefix="${AUTONOMICS_OUTPUT0%.json}"`) and `--log` output routing
  are preserved verbatim.
- fit1 vs fit2 differ exactly as in the legacy wrapper: the `fit1`/`fit2`
  analysis token, the four extra trait/params flags on fit2
  (`AUTONOMICS_INPUT1..3`), and the fit-sequence table
  (`fit_sequence(fit2, fast_run)`), expressed as one script per kind with
  an in-script branch over `MIXER_FAST_RUN`.
- Gzip sumstats need no `case *.gz` stanza: the wrapper passed inputs
  straight to mixer.py, which reads gzip natively (both migration
  fixtures are `.sumstats.gz`).
