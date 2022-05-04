# Steps to create a private-eks-cluster

1. create a cloud9 environment
2. create a private eks cluster
  a. download the file https://github.com/nigamshashank/private-eks-cluster/blob/main/private-eks-cluster.yaml
  b. run the command : 'eksctl create cluster -f private-eks-cluster.yaml'
4. Make changes in networking
5. Deploy an image to ECR 
6. Deploy application on the cluster
