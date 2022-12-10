### Terraform is used to provison both EKS kubernetes Infrastructure & deploy Kubernetes app

Terraform is a free and open-source infrastructure as code (IAC) that can help to automate the deployment, configuration, and management of the remote servers. Terraform can manage both existing service providers and custom in-house solutions.

![1](https://github.com/bijubayarea/bah-terraform-eks-website-deployment/blob/main/images/1.png)



This terraform github repo deploys simple nginx application in EKS cluster
* Create the Kubernetes deployment using "personal-website" image with replicas=2 in node_group_one
* Create a service of type=LoadBalancer  to expose app for simple external access


**Desired Output:**

![2](https://github.com/bijubayarea/bah-terraform-eks-website-deployment/blob/main/images/6.png)

**Prerequisites:**

* EKS access
* Basic understanding of AWS, Terraform & Kubernetes
* GitHub Account

# Part 1: Terraform scripts for the Kubernetes cluster.

**Step 1:  Create `.tf` file for accessing EKS cluster tfstate**

* Create `providers.tf` file and add below content in it to access remote s3 backend
  ```
  data "terraform_remote_state" "eks" {
    backend = "s3"
  
    config = {
      bucket = "bijubayarea-s3-remote-backend-deadbeef"
      key    = "test-terraform-eks-cluster/terraform.tfstate"
      region = var.region
    }
  }
  ```
* Retrieve EKS cluster information
  ```
  provider "aws" {
  region                   = data.terraform_remote_state.eks.outputs.region
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "vscode-user"
  }
  
  data "aws_eks_cluster" "cluster" {
    name = data.terraform_remote_state.eks.outputs.cluster_id
  }
  ```

**Step 2:  Create `.tf` file for storing Kubernetes provider**

* Create `providers.tf` file and add below content in it
  ```
  provider "kubernetes" {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        data.aws_eks_cluster.cluster.name
      ]
    }
  }
  ```
 
**Step 3:  Create `.tf` file for K8s deployment : Personal website** 

* Create `k8s-deployment.tf` file for VPC and add below content in it

* create k8s deployment "personal-website" with replicas=2
* pod containers: iamge=personal-website:v2.1

  ```
  containers:
      - name: personal-website
        image: docker.io/bijubayarea/personal-website:v2.1
        ports:
        - containerPort: 80
          protocol: TCP
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 50Mi
      
  ```

**Step 4: Create .tf file to expose k8s deploy as service=Loadbalancer**

* Create `k8s-service.tf` file for k8s service and add below content in it
* Below in yaml format for easier readabilty (But terraform code used to deploy)

  ```
  apiVersion: v1
  kind: Service
  metadata:
    name: nginx-service
    labels:
      personal-website
  spec:
    ports:
    - nodePort: 31754
      port: 80
      protocol: TCP
      targetPort: 80
    selector:
      app: personal-website
    type: LoadBalancer
  ```
  

**Step 5: Create .tf file for outputs for K8s LoadBalancer**

* Create `outputs.tf` file and add below content in it

  ```
  output "lb_ip" {
    value = kubernetes_service.web-service.status.0.load_balancer.0.ingress.0.hostname
  }

  ```
* output the name of the LoadBalancer.

 ```
  Outputs:

  load_balancer_ip = "a5499191dfdf84a67806f20ef474042c-986305581.us-west-2.elb.amazonaws.com"

  ```


**Step 6: Store our code to GitHub Repository**

* store the code in the GitHub repository

![2](https://github.com/bijubayarea/bah-terraform-eks-website-deployment/blob/main/images/2.png)

**Step 7: Initialize the working directory**

* Run `terraform init` command in the working directory, which will download all the necessary providers and all the modules

**Step 8: Create a terraform plan**

* Run `terraform plan` command in the working directory, which  will give the execution plan

  ```
  Plan: 6 to add, 0 to change, 0 to destroy.
  Changes to Outputs:
  + load_balancer_ip           = (known after apply)

  ```


**Step 9: Create the k8s app & service on EKS**

* Run `terraform apply` command in the working directory which will create the Kubernetes k8s deployment, service & load balancer
* Terraform will create the below resources on EKS

* k8s deployment
* k8s service


**Step 10: Check output of terraform apply**

* Output for `terraform plan` command 

  ```
  $ terraform output
  load_balancer_ip = "a5499191dfdf84a67806f20ef474042c-986305581.us-west-2.elb.amazonaws.com"

  ```

**Step 11: Set kubeconfig to access EKS kubernetes cluster using kubectl**

* retrieve the access credentials for your cluster from output and configure kubectl

  ```
  aws eks --region $(terraform output -raw region) update-kubeconfig \
    --name $(terraform output -raw cluster_name)

  ```


**Step 12: Verify the resources on AWS**

* Navigate to your EKS cluster and verify the resources

1. k8s deployment:
  ```
  $ kubectl get nodes
  NAME                                       STATUS   ROLES    AGE    VERSION
  ip-10-0-1-233.us-west-2.compute.internal   Ready    <none>   117m   v1.23.13-eks-fb459a0
  ip-10-0-1-68.us-west-2.compute.internal    Ready    <none>   117m   v1.23.13-eks-fb459a0
  ip-10-0-2-5.us-west-2.compute.internal     Ready    <none>   117m   v1.23.13-eks-fb459a0
  ip-10-0-3-251.us-west-2.compute.internal   Ready    <none>   117m   v1.23.13-eks-fb459a0
  
  $  kubectl get deploy personal-website -o wide
  NAME               READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS         IMAGES                                        SELECTOR
  personal-website   2/2     2            2           98m   personal-website   docker.io/bijubayarea/personal-website:v2.1   app=personal-website
  
  $ kubectl  get pods -o wide
  NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE                                       NOMINATED NODE   READINESS GATES
  personal-website-698d8c97b4-hhgx7   1/1     Running   0          37m   10.0.1.193   ip-10-0-1-233.us-west-2.compute.internal   <none>           <none>
  personal-website-698d8c97b4-p8qmk   1/1     Running   0          37m   10.0.2.144   ip-10-0-2-5.us-west-2.compute.internal     <none>           <none>

  ```
![3](https://github.com/bijubayarea/bah-terraform-eks-website-deployment/blob/main/images/3.png)

2. k8s service=LoadBalancer:
   ```
   $ kubectl get svc -o wide
   NAME            TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)        AGE   SELECTOR
   kubernetes      ClusterIP      172.20.0.1       <none>                                                                    443/TCP        13h   <none>
   nginx-service   LoadBalancer   172.20.146.252   ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com   80:31754/TCP   9h    App=nginx-pod-node
   
   $ kubectl describe svc nginx-service 
   Name:                     nginx-service
   Namespace:                default
   Labels:                   <none>
   Annotations:              <none>
   Selector:                 App=nginx-pod-node
   Type:                     LoadBalancer
   IP Family Policy:         SingleStack
   IP Families:              IPv4
   IP:                       172.20.146.252
   IPs:                      172.20.146.252
   LoadBalancer Ingress:     ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
   Port:                     <unset>  80/TCP
   TargetPort:               80/TCP
   NodePort:                 <unset>  31754/TCP
   Endpoints:                10.0.1.100:80,10.0.2.90:80
   Session Affinity:         None
   External Traffic Policy:  Cluster
   Events:                   <none>

   ```
![4](https://github.com/bijubayarea/bah-terraform-eks-website-deployment/blob/main/images/4.png)


* Kubernetes cluster is ready 
* Verify access to NGINX application using browser or 'curl' command


**Step 13: Access NGINX using 'curl' & browser**

* Access the NBINX server, confirm load balance fucntionality provided by k8s service
* NBINX server displays POD_NAME, NODE_NAME, POD_NAMESPACE & POD_IP

  ```
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-pk2cz NODE:ip-10-0-2-251.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.2.90
  
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-5hvj8 NODE:ip-10-0-1-118.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.1.100
  
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-pk2cz NODE:ip-10-0-2-251.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.2.90
  
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-pk2cz NODE:ip-10-0-2-251.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.2.90
  
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-pk2cz NODE:ip-10-0-2-251.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.2.90
  
  $ curl -s ac32240ec0119446cbbad59de348fd7e-2131601910.us-west-2.elb.amazonaws.com
  Welcome to POD:nginx-b4988fd99-5hvj8 NODE:ip-10-0-1-118.us-west-2.compute.internal NAMESPACE:default POD_IP:10.0.1.100

  ```
  ![5](https://github.com/bijubayarea/bah-terraform-eks-website-deployment/blob/main/images/5.png)
