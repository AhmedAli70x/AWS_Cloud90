

vpc_id='vpc-01cf18e14d586c7a0'
check_acl=$( aws ec2 describe-network-acls --query "NetworkAcls[?VpcId=='vpc-01cf18e14d586c7a0' && Tags[?Key=='Name' && Value=='devops-acl']].[NetworkAclId]" --output text | head -n 1 )


if [ -z "$check_acl" ]; then

    echo "ACL will be created"

    acl_id=$( aws ec2 create-network-acl   --vpc-id  $vpc_id --tag-specifications  'ResourceType=network-acl,Tags=[{Key=Name,Value=devops-acl}]'  | grep -oP '(?<="NetworkAclId": ")[^"]*' )

else 
    echo "ACL already exist"
    acl_id=$check_acl
fi


echo "new acl id is $acl_id"

my_ip=""
echo "getting your IP"
my_ip=$(curl -s https://api64.ipify.org)

my_ip1="$my_ip/32"
echo "this is my ip $my_ip1"
x = y + z

echo "\\n ----------------"
aws ec2 create-network-acl-entry \
  --network-acl-id $acl_id \
  --rule-number 100 \
  --protocol -1 \
  --rule-action allow \
  --ingress \
  --cidr "$my_ip/32"

echo "Inbound rule added to your IP, allow"

echo "\\n ----------------"
aws ec2 create-network-acl-entry \
  --network-acl-id $acl_id \
  --rule-number 100 \
  --protocol -1 \
  --rule-action allow \
  --egress \
  --cidr "$my_ip/32"


echo "Inbound rule added to your IP, allow"

subnet_id=$(aws ec2 describe-subnets --region eu-west-2 --filters "Name=tag:Name,Values=sub-public-1-devops90" --query "Subnets[0].SubnetId" --output text)

echo "Associate ID $subnet_id"

acl_assoc_id=$(aws ec2 describe-network-acls --region eu-west-2 --query "NetworkAcls[*].Associations[?SubnetId=='$subnet_id'].NetworkAclAssociationId" --output text)

echo "Associate ID $acl_assoc_id"
 


if [ "$acl_assoc_id" != "" ];  then

  response=$(aws ec2 replace-network-acl-association  --region eu-west-2 --association-id "$acl_assoc_id" --network-acl-id "$acl_id" --output text)
  echo "response  $response"
  if [ "$response" != "" ]; then
  echo "New ACL has been associated to the public subnet"

  fi

else

echo "No ACL available to be assocaited"

fi





