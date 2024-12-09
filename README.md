# Terraform Project with Python and AWS CloudWatch

This repository contains a **Terraform** project that provisions infrastructure on **AWS** and integrates it with **AWS CloudWatch** for monitoring. The infrastructure includes various AWS resources, and the Python code is used to interact with AWS CloudWatch to monitor logs, metrics, and set up alerts.

## Project Structure

The project is structured as follows:

```
.
├── main.tf            # Terraform configuration file that defines the resources
├── variables.tf       # Terraform variables for configuration
├── outputs.tf         # Output values of the deployed resources
├── python/
│   ├── cloudwatch.py  # Python script to interact with CloudWatch
├── README.md          # This file
└── provider.tf        # Terraform provider configuration (AWS)
```

### Terraform Files

- `main.tf`: Contains the primary Terraform configuration, where AWS resources (such as EC2, Lambda, or S3) are defined. It may also include CloudWatch log groups, alarms, or dashboards.
- `variables.tf`: Defines input variables that are used in the `main.tf` to configure resources.
- `outputs.tf`: Defines the output values (e.g., CloudWatch log group names, alarm ARNs) that you might need after deploying the infrastructure.

### Python Directory

- `cloudwatch.py`: A Python script that uses the AWS SDK (`boto3`) to interact with CloudWatch. This script can fetch CloudWatch metrics, logs, or even automate tasks such as creating or deleting log groups, setting up alarms, etc.

## Prerequisites

Before running this Terraform project, ensure you have the following:

1. **Terraform** installed on your machine.
   - You can download Terraform from [https://www.terraform.io/downloads.html](https://www.terraform.io/downloads.html).
   
2. **Python** installed (preferably Python 3.x).
   - Install Python from [https://www.python.org/downloads/](https://www.python.org/downloads/).
   
3. **AWS CLI** configured with appropriate permissions to deploy resources.
   - You can configure the AWS CLI by running:
     ```bash
     aws configure
     ```

4. **boto3** (Python SDK for AWS):
   - Install boto3 via pip:
     ```bash
     pip install boto3
     ```

## Setup

### 1. **Initialize Terraform**

In the root of the project, initialize the Terraform working directory. This will download the necessary provider plugins.

```bash
terraform init
```

### 2. **Configure AWS Provider**

In the `provider.tf` file, specify your AWS region and credentials (either via environment variables or the `aws configure` command):

```hcl
provider "aws" {
  region = "us-west-2"  # Change to your desired region
}
```

### 3. **Apply Terraform Configuration**

To apply the configuration and deploy the infrastructure, run:

```bash
terraform apply
```

Terraform will show a plan of the resources it will create. Review it and type `yes` to proceed.

### 4. **Python Script to Interact with CloudWatch**

Once the Terraform infrastructure is provisioned, you can use the Python script (`cloudwatch.py`) to interact with CloudWatch. You can customize this script to retrieve logs, metrics, or set up CloudWatch alarms.

#### Example Usage of Python Script:

- To fetch CloudWatch logs:
    ```python
    import boto3

    client = boto3.client('logs')

    # List log groups
    response = client.describe_log_groups()
    for group in response['logGroups']:
        print(group['logGroupName'])
    ```

You can expand the script as needed to monitor CloudWatch metrics, create dashboards, or set up alerts.

### 5. **Destroy the Resources**

Once you're done with the project and want to clean up the resources created by Terraform, run:

```bash
terraform destroy
```

This will remove all the resources created by Terraform, including CloudWatch configurations.

## Usage Example

Here’s an example of how the Terraform code might define a CloudWatch log group and a CloudWatch alarm:

```hcl
resource "aws_cloudwatch_log_group" "example" {
  name = "/aws/lambda/example"
}

resource "aws_cloudwatch_metric_alarm" "example_alarm" {
  alarm_name                = "ExampleAlarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  metric_name               = "Invocations"
  namespace                 = "AWS/Lambda"
  period                    = 60
  statistic                 = "Sum"
  threshold                 = 100
  alarm_description         = "Alarm when Lambda invocations exceed 100"
  actions_enabled           = true
  alarm_actions             = [aws_sns_topic.example.arn]
}
```

## Notes

- **Security**: Ensure your AWS credentials are managed securely. Do not hardcode sensitive information like API keys in your code.
- **Costs**: Running AWS resources, including CloudWatch, may incur charges. Be sure to monitor your AWS usage.

---

### Additional Features (Optional)

You may want to extend the functionality of this project, such as:

- Integrating with AWS Lambda to automate CloudWatch alerting.
- Configuring custom CloudWatch metrics.
- Adding additional AWS resources like S3 buckets or EC2 instances.

Feel free to modify the Python scripts or Terraform configuration to suit your need.
