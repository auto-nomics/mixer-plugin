set -eu

# Official fit-sequence tokens per run mode. The legacy wrapper chose these
# in Rust (fit_sequence(false, fast_run)); the plugin script owns the branch.
# --fit-sequence is nargs='+' upstream, so the unquoted expansion below
# word-splits into the same argv tokens the legacy wrapper emitted.
if [ "$MIXER_FAST_RUN" = "true" ]; then
  FIT_SEQUENCE="diffevo-fast neldermead-fast"
else
  FIT_SEQUENCE="diffevo neldermead"
fi

# Format guard over the official --chr2use grammar (comma-separated
# integers/ranges). The legacy wrapper validated this in Rust before
# starting the container; the plugin DSL has no string-pattern constraint,
# so the script keeps it fail-closed. mixer.py performs the full range
# validation itself.
case "$MIXER_CHR2USE" in
  ''|*[!0-9,-]*)
    echo "invalid chr2use: $MIXER_CHR2USE" >&2
    exit 2
    ;;
esac

# mixer.py appends .json to --out, so the JSON artifact path (minus its
# .json suffix) is the official output prefix (legacy: out_prefix).
out_prefix="${AUTONOMICS_OUTPUT0%.json}"

python /tools/mixer/precimed/mixer.py fit1 \
  --bim-file /panels/mixer_g1000_eur/stage_flat/chr@.bim \
  --ld-file /panels/mixer_g1000_eur/ld_mixer/1000G.EUR.chr@ \
  --extract /panels/mixer_g1000_eur/snps/g1000_eur_chr@.snps \
  --lib /tools/mixer/lib/libbgmg.so \
  --chr2use "$MIXER_CHR2USE" \
  --seed "$MIXER_SEED" \
  --threads "$MIXER_THREADS" \
  --kmax-pdf "$MIXER_KMAX_PDF" \
  --downsample-factor "$MIXER_DOWNSAMPLE_FACTOR" \
  --fit-sequence $FIT_SEQUENCE \
  --diffevo-fast-repeats "$MIXER_DIFFEVO_FAST_REPEATS" \
  --trait1-file "$AUTONOMICS_INPUT0" \
  --out "$out_prefix" \
  --log "$AUTONOMICS_OUTPUT1"
