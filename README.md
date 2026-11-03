# k3s-warehouse hardened

A small data warehouse on single-node k3s (MinIO, Spark ETL, PostgreSQL, Metabase), hardened against a deliberately vulnerable baseline. Covered areas:

- cluster: secrets encrypted at rest, API audit log
- secrets: random passwords, separate least-privilege accounts in PostgreSQL and MinIO
- workload isolation: default-deny NetworkPolicies, Pod Security `restricted`, non-root, read-only root filesystem
- traffic between containers: TLS for PostgreSQL and MinIO, authenticated and encrypted Spark RPC
- temporary data: Spark cache and shuffle files encrypted on disk
- supply chain: Spark image scanned with Trivy, SBOM, keyless cosign signature verified by Kyverno

## 1. Cluster

```bash
sudo k3s-killall.sh
sudo cp cluster/config.yaml /etc/rancher/k3s/config.yaml
sudo cp cluster/audit-policy.yaml /etc/rancher/k3s/audit-policy.yaml
sudo rm -f /etc/rancher/k3s/registries.yaml
sudo systemctl start k3s

mkdir -p ~/.kube && sudo install -m 600 -o $USER -g $USER /etc/rancher/k3s/k3s.yaml ~/.kube/config
export KUBECONFIG=~/.kube/config
```

## 2. Passwords and TLS certificates (once)

```bash
bash generate-secrets.sh
```

## 3. Kyverno (once per cluster)

```bash
helm install kyverno kyverno --repo https://kyverno.github.io/kyverno --version 3.9.1 \
  --namespace kyverno --create-namespace --wait

kubectl apply -k policies/kyverno/
```

## 4. Stack, Spark, network policies

```bash
kubectl apply -k stack/
kubectl apply -k spark/
kubectl apply -k policies/network/
```

The Spark image is built, scanned, signed and published by the `.github/workflows/spark-image.yml` workflow after a push to `spark/`. The version in `spark/VERSION` must match the image tag in `spark/20-sales-etl.yaml`.

The ETL runs every 10 minutes. To run it manually:

```bash
kubectl -n processing create job etl-$(date +%s) --from=cronjob/sales-etl
kubectl -n processing get jobs -w
```

## Access (port-forward, also works from Windows via localhost)

| Service       | Command                                                     | Address                  |
| ------------- | ----------------------------------------------------------- | ------------------------ |
| Metabase      | `kubectl -n bi port-forward svc/metabase 3000:3000`         | <http://localhost:3000>  |
| MinIO console | `kubectl -n ingest port-forward svc/minio 9001:9001`        | <https://localhost:9001> |
| PostgreSQL    | `kubectl -n warehouse port-forward svc/postgres 5432:5432`  | localhost:5432           |
| Spark UI      | `kubectl -n processing port-forward svc/spark-ui 4040:4040` | only while ETL runs      |

Metabase login `admin@bhd.local`, password: `grep MB_ADMIN_PASSWORD stack/secrets/bi.env`.

## Check

```bash
kubectl get pods -A
kubectl -n warehouse exec postgres-0 -- psql -U postgres -d warehouse -c 'select count(*) from dwh.sales_daily'
```

## Removal

```bash
kubectl delete -k policies/network/
kubectl delete -k spark/
kubectl delete -k stack/
```

## Reset

```bash
bash reset.sh
```
