# Kubernetes 3-Tier Todo Application on AWS EKS

This project demonstrates the deployment of a simple three-tier Todo application on Amazon EKS using Docker and Kubernetes.

## Architecture

```text
                         Internet
                            |
                            v
                    AWS Load Balancer
                            |
                            v
                 NGINX Ingress Controller
                    /                 \
                   /                   \
                  v                     v
       frontend.todo.com         backend.todo.com
                  |                     |
                  v                     v
       frontend-service          backend-service
             :3000                    :5000
                  |                     |
                  v                     v
          Frontend Pod             Backend Pod
             :80                     :80
                                        |
                                        v
                                  database:3306
                                        |
                                        v
                                    MySQL Pod
                                        |
                                        v
                                  PVC -> AWS EBS
```

## Technologies

- Docker & Docker Compose
- Docker Hub
- Kubernetes
- Amazon EKS
- Amazon EC2
- Amazon EBS
- AWS EBS CSI Driver
- EKS Pod Identity
- NGINX Ingress Controller
- Helm
- Apache
- PHP
- MySQL
- GitHub

---

## 1. Local Development with Docker Compose

The application consists of three services:

- **Frontend** – Apache web server
- **Backend** – PHP/Apache API
- **Database** – MySQL

The complete application was first tested locally using Docker Compose.

```bash
docker compose up -d
docker compose ps
```

Local ports:

```text
Frontend: localhost:3000 -> Container:80
Backend:  localhost:5000 -> Container:80
MySQL:    localhost:3306 -> Container:3306
```

The backend communicates with MySQL through the Docker Compose service name `database`.

Reference: `docker-compose.yml`

---

## 2. Build and Push Docker Images

Separate Docker images were created for all three application layers.

```text
brhmkskn/k8sproject_frontend:proje
brhmkskn/k8sproject_backend:proje
brhmkskn/k8sproject_database:proje
```

The images were pushed to Docker Hub and are used by the Kubernetes Deployments.

```bash
docker login
docker push brhmkskn/k8sproject_frontend:proje
docker push brhmkskn/k8sproject_backend:proje
docker push brhmkskn/k8sproject_database:proje
```

---

## 3. Create Amazon EKS Cluster

An Amazon EKS cluster named `todo-cluster` was created in the `eu-central-1` region.

EKS Auto Mode was disabled because the project uses a manually configured Managed Node Group.

A dedicated IAM role was created for the EKS control plane with the required EKS permissions and trust relationship.

```text
Cluster: todo-cluster
Region: eu-central-1
```

---

## 4. Create Managed Node Group

A Managed Node Group was added to the EKS cluster.

```text
Instance Type: t3.medium
Capacity Type: On-Demand
Desired Nodes: 2
Minimum Nodes: 2
Maximum Nodes: 2
```

A separate IAM role was used by the EC2 worker nodes.

The two worker nodes were verified with:

```bash
kubectl get nodes
```

Both nodes must have the status:

```text
Ready
```

---

## 5. Connect Local kubectl to EKS

AWS CLI credentials were configured locally:

```bash
aws configure
```

The AWS identity was verified:

```bash
aws sts get-caller-identity
```

The local Kubernetes configuration was then connected to EKS:

```bash
aws eks update-kubeconfig \
  --region eu-central-1 \
  --name todo-cluster
```

Connection test:

```bash
kubectl get nodes
```

---

## 6. Configure EKS Add-ons

The basic Kubernetes networking components were enabled:

- Amazon VPC CNI
- CoreDNS
- kube-proxy

For persistent storage, the following components were also configured:

- EKS Pod Identity Agent
- AWS EBS CSI Driver

The EBS CSI Driver allows Kubernetes to dynamically provision Amazon EBS volumes.

A dedicated IAM role was created for the EBS CSI Driver and associated with its Kubernetes ServiceAccount through EKS Pod Identity.

---

## 7. Configure Persistent MySQL Storage

MySQL requires persistent storage so that database data survives Pod recreation.

A custom Kubernetes StorageClass using:

```text
ebs.csi.aws.com
```

was created.

A `5 GiB` PersistentVolumeClaim was then created for MySQL.

The storage flow is:

```text
MySQL Pod
    |
    v
PersistentVolumeClaim
    |
    v
PersistentVolume
    |
    v
Amazon EBS
```

The MySQL data directory `/var/lib/mysql` is mounted to this persistent volume.

References:

```text
storageclass.yaml
mysql-pvc.yaml
```

Storage can be verified with:

```bash
kubectl get storageclass
kubectl get pvc
kubectl get pv
```

---

## 8. Create Kubernetes Secrets

Database connection information was moved from the Docker Compose environment into a Kubernetes Secret.

The secret contains:

```text
DB_HOST
DB_USERNAME
DB_PASSWORD
DB_NAME
```

The backend receives these values as environment variables.

This allows the application configuration to be separated from the Deployment definition.

Reference: `dbsecret`

> Real credentials should never be committed to the repository.

---

## 9. Deploy MySQL

The MySQL Deployment was deployed first.

It uses:

- MySQL Docker image
- Kubernetes Secret configuration
- `mysql-pvc`
- CPU and memory requests/limits

A ClusterIP Service named `database` exposes MySQL internally on port `3306`.

The backend therefore connects to:

```text
database:3306
```

The database is not directly exposed to the Internet.

Reference: `database.yaml`

---

## 10. Deploy Backend

The PHP backend was deployed to EKS using the Docker Hub image.

The backend receives its database configuration from the Kubernetes Secret.

Its Service configuration is:

```text
backend-service:5000
        |
        v
Backend Pod:80
```

The backend uses Kubernetes DNS to reach MySQL through the `database` Service.

Reference: `backend.yaml`

---

## 11. Deploy Frontend

The Apache frontend was deployed using its Docker Hub image.

Its Service configuration is:

```text
frontend-service:3000
        |
        v
Frontend Pod:80
```

CPU and memory requests/limits were also configured.

Reference: `frontend.yaml`

---

## 12. Frontend Init Container

An init container was added to the frontend Pod.

Before the frontend container starts, the init container downloads the latest `index.html` from the GitHub `master` branch.

```text
Frontend Pod Created
        |
        v
Init Container Starts
        |
        v
Download latest index.html
        |
        v
Shared Volume
        |
        v
Frontend Container Starts
```

The init container and frontend container share an `emptyDir` volume.

This means a newly created frontend Pod can retrieve the latest version of `index.html` before Apache starts.

Reference: `frontend.yaml`

A new Pod can be created with:

```bash
kubectl rollout restart deployment frontend-deployment
```

---

## 13. Install NGINX Ingress Controller

NGINX Ingress Controller was installed using Helm.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

Installation:

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

Verification:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

The NGINX Controller uses a Kubernetes Service of type `LoadBalancer`.

AWS therefore provisions an external Load Balancer for incoming traffic.

---

## 14. Configure Ingress

Host-based routing was configured for the frontend and backend.

```text
frontend.todo.com
        |
        v
frontend-service:3000


backend.todo.com
        |
        v
backend-service:5000
```

The frontend JavaScript communicates with the backend through:

```text
http://backend.todo.com
```

The browser does not access port `5000` directly. NGINX receives the HTTP request and forwards it internally to `backend-service:5000`.

Reference: `ingress.yaml`

Ingress can be verified with:

```bash
kubectl get ingress
kubectl describe ingress my-ingress
```

---

## 15. Local Domain Configuration

For development/testing, the custom hostnames were mapped locally to the AWS Load Balancer.

The Load Balancer address was resolved using:

```bash
nslookup <AWS-LOAD-BALANCER-DNS>
```

The following hostnames were configured locally:

```text
frontend.todo.com
backend.todo.com
```

After updating the Windows hosts file:

```powershell
ipconfig /flushdns
```

The application can be accessed at:

```text
http://frontend.todo.com
```

and the backend at:

```text
http://backend.todo.com
```

---

## 16. Resource Management

CPU and memory requests/limits were defined for the application containers.

This allows Kubernetes to:

- Make better Pod scheduling decisions
- Reserve required resources
- Prevent containers from consuming unlimited CPU or memory

The resource definitions are available directly in the corresponding Deployment YAML files.

---

## 17. Verification

The complete Kubernetes environment can be checked with:

```bash
kubectl get nodes
kubectl get pods
kubectl get svc
kubectl get ingress
kubectl get pvc
kubectl get pv
```

Application logs can be inspected with:

```bash
kubectl logs deployment/backend
```

The frontend init container can be checked with:

```bash
kubectl logs deployment/frontend-deployment -c fetch-index
```

---

## Final Result

The final application runs as a complete three-tier architecture on Amazon EKS:

```text
Internet
   |
   v
AWS Load Balancer
   |
   v
NGINX Ingress
   |
   +---- frontend.todo.com
   |          |
   |          v
   |    Frontend Service
   |          |
   |          v
   |     Frontend Pod
   |
   +---- backend.todo.com
              |
              v
        Backend Service
              |
              v
         Backend Pod
              |
              v
        Database Service
              |
              v
          MySQL Pod
              |
              v
         PVC -> AWS EBS
```

The project demonstrates:

- Three-tier application architecture
- Docker containerization
- Docker Compose local development
- Amazon EKS cluster configuration
- Managed EC2 worker nodes
- Kubernetes Deployments and Services
- Kubernetes Secrets
- Persistent MySQL storage with Amazon EBS
- EBS CSI Driver and EKS Pod Identity
- Init Containers
- CPU and memory resource management
- NGINX Ingress Controller
- AWS Load Balancer integration
- Host-based routing
