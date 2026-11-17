# Guide des Commandes Impératives (`webapp-color`)

Ce guide regroupe les commandes `kubectl` impératives équivalentes aux trois manifestes déclaratifs du projet (`webapp-color-deploy.yaml`, `webapp-color-deploys.yaml` et `webapp-color-sts.yaml`), ainsi que l'exposition via **Traefik Ingress**.

> **Note technique :** Par défaut, `kubectl create deployment` et `kubectl create service` génèrent automatiquement le label `app=<nom-de-la-ressource>`. Les commandes `kubectl patch` et `kubectl set selector` ci-dessous permettent d'aligner strictement les labels et sélecteurs sur vos fichiers YAML.

---

## 1. Équivalent de `k8s/webapp-color-deploy.yaml`
*(1 Deployment de 3 réplicas avec couleur aléatoire au démarrage + 1 Service LoadBalancer)*

```bash
# Création du Deployment 'webapp-dp' avec sélection aléatoire de la couleur
kubectl create deployment webapp-dp \
  --image=kodekloud/webapp-color \
  --replicas=3 \
  -- /bin/sh -c 'COLORS="red green blue blue2 pink darkblue"; export APP_COLOR=$(echo $COLORS | tr " " "\n" | shuf -n 1); python app.py'

# Alignement des labels et du sélecteur sur 'app: webapp-color-dp'
kubectl patch deployment webapp-dp --type='json' -p='[
  {"op": "replace", "path": "/spec/selector/matchLabels", "value": {"app": "webapp-color-dp"}},
  {"op": "replace", "path": "/spec/template/metadata/labels", "value": {"app": "webapp-color-dp"}}
]'

# Création du Service LoadBalancer et ciblage du label 'app=webapp-color-dp'
kubectl create service loadbalancer webapp-color-svc --tcp=80:8080
kubectl set selector service webapp-color-svc app=webapp-color-dp
```

---

## 2. Équivalent de `k8s/webapp-color-deploys.yaml`
*(3 Deployments distincts par couleur partageant un label commun `app: webapp-color` + 1 Service LoadBalancer unique)*

```bash
# --- Deployment 1 : Bleu ---
kubectl create deployment webapp-blue --image=kodekloud/webapp-color --replicas=1
kubectl set env deployment/webapp-blue APP_COLOR=blue
kubectl patch deployment webapp-blue --type='json' -p='[
  {"op": "replace", "path": "/spec/selector/matchLabels", "value": {"app": "webapp-color", "color": "blue"}},
  {"op": "replace", "path": "/spec/template/metadata/labels", "value": {"app": "webapp-color", "color": "blue"}}
]'

# --- Deployment 2 : Vert ---
kubectl create deployment webapp-green --image=kodekloud/webapp-color --replicas=1
kubectl set env deployment/webapp-green APP_COLOR=green
kubectl patch deployment webapp-green --type='json' -p='[
  {"op": "replace", "path": "/spec/selector/matchLabels", "value": {"app": "webapp-color", "color": "green"}},
  {"op": "replace", "path": "/spec/template/metadata/labels", "value": {"app": "webapp-color", "color": "green"}}
]'

# --- Deployment 3 : Rose ---
kubectl create deployment webapp-pink --image=kodekloud/webapp-color --replicas=1
kubectl set env deployment/webapp-pink APP_COLOR=pink
kubectl patch deployment webapp-pink --type='json' -p='[
  {"op": "replace", "path": "/spec/selector/matchLabels", "value": {"app": "webapp-color", "color": "pink"}},
  {"op": "replace", "path": "/spec/template/metadata/labels", "value": {"app": "webapp-color", "color": "pink"}}
]'

# --- Service LoadBalancer unique ciblant les 3 couleurs ---
kubectl create service loadbalancer webapp-color-lb --tcp=80:8080
kubectl set selector service webapp-color-lb app=webapp-color
```

---

## 3. Équivalent de `k8s/webapp-color-sts.yaml`
*(1 StatefulSet de 3 réplicas avec couleur déterministe basée sur l'index du pod `-0`, `-1`, `-2` + 1 Service NodePort)*

```bash
# Création du StatefulSet 'webapp-sts' (pas de commande 'kubectl create statefulset' native)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: webapp-sts
spec:
  serviceName: "webapp-color"
  replicas: 3
  selector:
    matchLabels:
      app: webapp-color-sts
  template:
    metadata:
      labels:
        app: webapp-color-sts
    spec:
      containers:
      - name: webapp
        image: kodekloud/webapp-color
        command: ["/bin/sh", "-c"]
        args:
          - |
            case \$HOSTNAME in
              *-0) export APP_COLOR=blue ;;
              *-1) export APP_COLOR=green ;;
              *-2) export APP_COLOR=pink ;;
            esac
            python app.py
EOF

# Création du Service NodePort et ciblage du label 'app=webapp-color-sts'
kubectl create service nodeport webapp-color-lb-sts --tcp=80:8080
kubectl set selector service webapp-color-lb-sts app=webapp-color-sts
```

---

## 4. Exposition via Traefik Ingress (Accès par nom de domaine)

Sur **K3s**, Traefik occupe déjà les ports `80` et `443` de l'IP du nœud (`192.168.60.80`) via `svclb-traefik`. Pour exposer une application via un nom de domaine sans conflit de port :

```bash
# Exemple d'exposition de 'webapp-color-lb' en ClusterIP via Ingress
kubectl create ingress webapp-color-ingress \
  --class=traefik \
  --rule="webapp.local/*=webapp-color-lb:80"
```

### Configuration DNS locale (Machine hôte Windows)
Ajouter l'entrée suivante dans `C:\Windows\System32\drivers\etc\hosts` (en tant qu'Administrateur) :
```text
192.168.60.80   webapp.local
```
*Alternative sans modifier le fichier `hosts` : remplacer `webapp.local` par `webapp.192.168.60.80.nip.io`.*

---

## 5. Commandes de Vérification & Nettoyage

```bash
# Vérifier l'état des pods et leurs labels
kubectl get pods --show-labels

# Vérifier que chaque Service est bien relié à ses Endpoints (IPs des pods)
kubectl get endpoints webapp-color-svc webapp-color-lb webapp-color-lb-sts

# Vérifier les services et les ports NodePort attribués
kubectl get svc

# Nettoyage complet des ressources créées
kubectl delete deployment webapp-dp webapp-blue webapp-green webapp-pink --ignore-not-found
kubectl delete statefulset webapp-sts --ignore-not-found
kubectl delete svc webapp-color-svc webapp-color-lb webapp-color-lb-sts --ignore-not-found
kubectl delete ingress webapp-color-ingress --ignore-not-found
```
