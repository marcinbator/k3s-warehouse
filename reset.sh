#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

read -rp "Usunac stack, Spark, Kyverno, dane (PVC) i hasla? [y/N] " ans
[ "$ans" = "y" ] || exit 1

kubectl delete -k policies/kyverno/ --ignore-not-found || true
kubectl delete ns warehouse ingest bi processing --ignore-not-found --wait

helm uninstall kyverno -n kyverno --wait || true
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations -o name \
  | { grep kyverno || true; } | xargs -r kubectl delete
kubectl get crd -o name | { grep -E '\.(kyverno\.io|wgpolicyk8s\.io)$' || true; } | xargs -r kubectl delete
kubectl delete ns kyverno --ignore-not-found --wait

rm -f stack/secrets/*.env spark/secrets/*.env

