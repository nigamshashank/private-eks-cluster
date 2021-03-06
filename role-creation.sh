#!/bin/bash -ex

# Custom policy for S3
cat << EOF > s3-policy-document
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:CreateBucket",
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:DeleteBucket"
            ],
            "Resource": [
                "arn:aws:s3:::*",
                "arn:aws:s3:::*/*"
            ]
        }
    ]
}
EOF
aws iam create-policy --policy-name private-eks-s3 --policy-document file://s3-policy-document

# Custom policy for IAM and SSM limited access
cat << EOF > iam-policy-document 
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:GetInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:GetRole",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:AttachRolePolicy",
                "iam:PutRolePolicy",
                "iam:ListInstanceProfiles",
                "iam:AddRoleToInstanceProfile",
                "iam:ListInstanceProfilesForRole",
                "iam:PassRole",
                "iam:DetachRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:GetRolePolicy",
                "iam:GetOpenIDConnectProvider",
                "iam:TagOpenIDConnectProvider",
                "iam:CreateOpenIDConnectProvider",
                "iam:DeleteOpenIDConnectProvider",
                "iam:ListAttachedRolePolicies",
                "iam:TagRole"
            ],
            "Resource": [
                "arn:aws:iam::${ACCOUNT_ID}:instance-profile/eksctl-*",
                "arn:aws:iam::${ACCOUNT_ID}:role/eksctl-*",
                "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/*",
                "arn:aws:iam::${ACCOUNT_ID}:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup",
                "arn:aws:iam::${ACCOUNT_ID}:role/eksctl-managed-*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:GetRole"
            ],
            "Resource": [
                "arn:aws:iam::${ACCOUNT_ID}:role/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": [
                        "eks.amazonaws.com",
                        "eks-nodegroup.amazonaws.com",
                        "eks-fargate.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::${ACCOUNT_ID}:role/${EKS_ROLE_NAME}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:StartSession"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:ListLogDeliveries"
            ],
            "Resource": "*"
        }
    ]
}
EOF
aws iam create-policy --policy-name private-eks-iam-limited --policy-document file://iam-policy-document

# Custom policy for EKS and ECR Access
cat << EOF > eks-policy-document
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "eks:*",
            "Resource": "*"
        },
        {
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters"
            ],
            "Resource": [
                "arn:aws:ssm:*:${ACCOUNT_ID}:parameter/aws/*",
                "arn:aws:ssm:*::parameter/aws/*"
            ],
            "Effect": "Allow"
        },
        {
            "Action": [
                "kms:CreateGrant",
                "kms:DescribeKey"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:CreateRepository",
                "ecr:CompleteLayerUpload",
                "ecr:GetAuthorizationToken",
                "ecr:UploadLayerPart",
                "ecr:InitiateLayerUpload",
                "ecr:DeleteRepository",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:DescribeRepositories"
            ],
            "Resource": "*"
        }
    ]
}
EOF
aws iam create-policy --policy-name private-eks-all --policy-document file://eks-policy-document

# Role trust policy
cat << EOF > trust-policy-document
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role and instance profile for role
aws iam create-role --role-name ${EKS_ROLE_NAME} --assume-role-policy-document file://trust-policy-document
aws iam create-instance-profile --instance-profile-name ${EKS_ROLE_NAME}
aws iam add-role-to-instance-profile --role-name ${EKS_ROLE_NAME} --instance-profile-name ${EKS_ROLE_NAME}

# Attach AWS managed policies to role
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --role-name ${EKS_ROLE_NAME}
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy --role-name ${EKS_ROLE_NAME}
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSCloudFormationFullAccess --role-name ${EKS_ROLE_NAME}
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore --role-name ${EKS_ROLE_NAME}

# Attach custom managed policies to role
aws iam attach-role-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/private-eks-all --role-name ${EKS_ROLE_NAME}
aws iam attach-role-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/private-eks-iam-limited --role-name ${EKS_ROLE_NAME}
aws iam attach-role-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/private-eks-nw-fw --role-name ${EKS_ROLE_NAME}
aws iam attach-role-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/private-eks-s3 --role-name ${EKS_ROLE_NAME}

# Clean up
rm -rf *-document
