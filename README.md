# k3s-warehouse: wariant utwardzony

## 1. Klaster

```bash
sudo k3s-killall.sh
sudo cp cluster/config.yaml /etc/rancher/k3s/config.yaml
sudo cp cluster/audit-policy.yaml /etc/rancher/k3s/audit-policy.yaml
sudo rm -f /etc/rancher/k3s/registries.yaml
sudo systemctl start k3s

mkdir -p ~/.kube && sudo install -m 600 -o $USER -g $USER /etc/rancher/k3s/k3s.yaml ~/.kube/config
export KUBECONFIG=~/.kube/config
```

## 2. Hasła i certyfikaty TLS (raz)

```bash
bash generate-secrets.sh
```

## 3. Kyverno (raz na klaster)

```bash
helm install kyverno kyverno --repo https://kyverno.github.io/kyverno --version 3.9.1 \
  --namespace kyverno --create-namespace --wait

kubectl apply -k policies/kyverno/
```

## 4. Stack, Spark, polityki sieciowe

```bash
kubectl apply -k stack/
kubectl apply -k spark/
kubectl apply -k policies/network/
```

Obraz Sparka buduje, skanuje, podpisuje i publikuje workflow `.github/workflows/spark-image.yml` po pushu zmian w `spark/`. Wersja obrazu w `spark/VERSION` musi się zgadzać z tagiem w `spark/20-sales-etl.yaml`.

ETL uruchamia się co 10 minut. Ręcznie:

```bash
kubectl -n processing create job etl-$(date +%s) --from=cronjob/sales-etl
kubectl -n processing get jobs -w
```

## Dostęp (port-forward, działa też z Windows przez localhost)

| Usługa        | Komenda                                                     | Adres                 |
| ------------- | ----------------------------------------------------------- | --------------------- |
| Metabase      | `kubectl -n bi port-forward svc/metabase 3000:3000`         | http://localhost:3000 |
| MinIO konsola | `kubectl -n ingest port-forward svc/minio 9001:9001`        | https://localhost:9001 |
| PostgreSQL    | `kubectl -n warehouse port-forward svc/postgres 5432:5432`  | localhost:5432        |
| Spark UI      | `kubectl -n processing port-forward svc/spark-ui 4040:4040` | tylko w trakcie ETL   |

Login Metabase `admin@bhd.local`, hasło: `grep MB_ADMIN_PASSWORD stack/secrets/bi.env`.

## Sprawdzenie

```bash
kubectl get pods -A
kubectl -n warehouse exec postgres-0 -- psql -U postgres -d warehouse -c 'select count(*) from dwh.sales_daily'
```

## Usunięcie

```bash
kubectl delete -k policies/network/
kubectl delete -k spark/
kubectl delete -k stack/
```

## Reset przed demo

```bash
bash reset.sh
```

Usuwa namespace'y stacka i Sparka (razem z PVC Postgresa i MinIO), polityki i całe Kyverno (helm, webhooki, CRD) oraz pliki `*.env` z hasłami. Potem od nowa kroki 2-4.
