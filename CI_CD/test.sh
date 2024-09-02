lb_vpc_id=$(aws elbv2 describe-load-balancers --load-balancer-arns arn:aws:elasticloadbalancing:eu-west-2:500845238363:loadbalancer/net/prod-autoscaling-nlb/0b431d459a7839eb \
    --query "LoadBalancers[0].VpcId" --output text)

echo $lb_vpc_id