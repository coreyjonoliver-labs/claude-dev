#!/bin/bash
# Release gates for the build workflow (main only). The image is pushed BY
# DIGEST first (no tag); the human-readable tag is added only after the pushed
# image is proven to be the tested one and has been attested.
#
#   ci/release.sh verify   IMAGE DIGEST LOCAL  # pushed config digest == tested
#   ci/release.sh tag      IMAGE DIGEST TAG    # point IMAGE:TAG at DIGEST, then check it
#
# Why config digests: build-push-action's `imageid` is whatever buildx writes to
# its iidfile, which is the CONFIG digest for a single image, the MANIFEST digest
# for an image loaded into a containerd image store, and the INDEX digest when the
# output is an index (e.g. with provenance attestations). The config digest is
# the one identity both sides share: it covers the layer diff_ids, env, user,
# entrypoint and timestamps, and is the same however the image is stored.
#
# Exit 1 = checked and wrong; exit 2 = could not evaluate. Both stop the job.
set -euo pipefail

die()  { echo "FAIL: $*" >&2; exit 1; }
cant() { echo "COULD NOT EVALUATE: $*" >&2; exit 2; }
HEX64='^sha256:[0-9a-f]{64}$'

# Config digest of an image in the local Docker store, read from `docker save`
# (works on both the classic and the containerd image store), with the config
# blob's own hash re-checked.
tested_config() {
  local ref="$1" tmp cfgpath want got
  tmp="$(mktemp -d)"
  docker save -o "$tmp/img.tar" "$ref" || cant "docker save $ref"
  tar -xf "$tmp/img.tar" -C "$tmp" manifest.json || cant "no manifest.json in the saved image"
  [ "$(jq 'length' "$tmp/manifest.json")" = 1 ] || cant "saved image holds more than one manifest"
  cfgpath="$(jq -r '.[0].Config' "$tmp/manifest.json")"
  want="$(printf '%s' "$cfgpath" | grep -oE '[0-9a-f]{64}')" || cant "config path '$cfgpath' carries no digest"
  tar -xf "$tmp/img.tar" -C "$tmp" "$cfgpath" || cant "config blob $cfgpath missing"
  got="$(sha256sum "$tmp/$cfgpath" | cut -d' ' -f1)"
  [ "$got" = "$want" ] || die "config blob hash $got != its name $want"
  jq -e '.os == "linux" and .architecture == "amd64"' "$tmp/$cfgpath" >/dev/null \
    || die "tested image is not linux/amd64"
  echo "sha256:$want"
}

# Config digest of IMAGE@DIGEST in the registry (a single manifest, or the one
# linux/amd64 manifest of an index).
pushed_config() {
  local image="$1" digest="$2" raw mt d cfg
  raw="$(docker buildx imagetools inspect --raw "$image@$digest")" || cant "inspect $image@$digest"
  mt="$(jq -r '.mediaType // empty' <<<"$raw")"
  case "$mt" in
    application/vnd.oci.image.manifest.v1+json|application/vnd.docker.distribution.manifest.v2+json) ;;
    application/vnd.oci.image.index.v1+json|application/vnd.docker.distribution.manifest.list.v2+json)
      d="$(jq -r '[.manifests[] | select(.platform.os == "linux" and .platform.architecture == "amd64")]
                 | if length == 1 then .[0].digest else empty end' <<<"$raw")"
      [[ "$d" =~ $HEX64 ]] || die "index $digest has no single linux/amd64 manifest"
      raw="$(docker buildx imagetools inspect --raw "$image@$d")" || cant "inspect $image@$d"
      ;;
    *) cant "unexpected media type '$mt' for $image@$digest" ;;
  esac
  cfg="$(jq -r '.config.digest // empty' <<<"$raw")"
  [[ "$cfg" =~ $HEX64 ]] || cant "no config digest in the pushed manifest"
  echo "$cfg"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  verify)
    [ $# = 3 ] || cant "usage: verify IMAGE DIGEST LOCAL"
    image="$1" digest="$2" local_ref="$3"
    [[ "$digest" =~ $HEX64 ]] || die "push returned no digest ('$digest')"
    tested="$(tested_config "$local_ref")"
    pushed="$(pushed_config "$image" "$digest")"
    echo "tested config=$tested"
    echo "pushed config=$pushed (manifest $digest)"
    [ "$tested" = "$pushed" ] || die "the pushed image is not the tested image"
    echo "verify: PASS"
    ;;
  tag)
    [ $# = 3 ] || cant "usage: tag IMAGE DIGEST TAG"
    image="$1" digest="$2" tag="$3"
    [[ "$digest" =~ $HEX64 ]] || die "bad digest '$digest'"
    # --prefer-index=false copies the single manifest as-is. The default WRAPS it
    # in a new index, so the tag would name a digest nothing attested (measured).
    docker buildx imagetools create --prefer-index=false --tag "$image:$tag" "$image@$digest" \
      || cant "imagetools create"
    got="$(docker buildx imagetools inspect --format '{{json .Manifest}}' "$image:$tag" | jq -r '.digest // empty')" \
      || cant "inspect $image:$tag"
    echo "$image:$tag -> $got"
    [ "$got" = "$digest" ] || die "$image:$tag points at $got, not the attested $digest"
    echo "tag: PASS"
    ;;
  *) cant "usage: $0 verify|tag ..." ;;
esac
