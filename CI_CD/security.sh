key_name="${env}-key-ec2-ssh"
security_group_name="${env}-main-sg"
RULES=(
        '{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "ssh"}]}'
    '{"IpProtocol": "-1", "UserIdGroupPairs": [{"GroupId": "<new-security-group-id>"}]}'
)

describe_ec2_key(){
    echo "Status: Getting EC2 Key..!"
    check_ec2_key=$(aws ec2 describe-key-pairs --key-names $key_name | grep -oP '(?<="KeyName": ")[^"]*')

    echo $check_ec2_key
    echo "--------------"
}

#Check if the Ec2 key exists
create_ec2_key(){
    echo "Status: Creating Ec2 Key"
    aws ec2 create-key-pair --key-name $key_name --key-format  pem --query 'KeyMaterial' --output text > "${key_name}.pem"
    if ! [ -f "${key_name}.pem" ]; then
            echo "Erro While Creating EC2 Key"
            exit 1

    else
        echo "Ec2 Key Created"

    fi
    echo "--------------"

}

create_secret(){
    echo "Status: Creating Secret..!"
    delete_secret

    secret_arn=$(aws secretsmanager create-secret --name "$key_name" --description "EC2 SSH Key" --secret-string file://"${key_name}.pem" | grep -oP "(?<=\"ARN\": \")[^\"]*")

    if [ "$secret_arn" == "" ]; then
        echo "Error While Creating Secret Key"
        exit 1
    else
        echo "Secret Key Created"
        rm "${key_name}.pem"
        echo $secret_arn
    fi
    echo "--------------"
}


describe_secret(){
    echo "Status: Descriping Key"
    secret_arn=$(aws secretsmanager describe-secret --secret-id $key_name | grep -oP '(?<="ARN": ")[^"]*')
    echo $secret_arn
    echo "--------------"
}

delete_ec2_key(){
    echo "Status: Deleting EC2 Key"
    aws ec2 delete-key-pair --key-name $key_name
    echo "--------------"
}

delete_secret(){
    echo "Status: Deleting Secret..."
    aws secretsmanager delete-secret --secret-id $key_name --force-delete-without-recovery  | grep -oP '(?<="ARN": ")[^"]*'
    echo "--------------"
} 

create_sg(){
    echo "Status: Creating SG...."
    check_sg=$(aws ec2 describe-security-groups --filters Name=group-name,Values=${env}-main-sg)
    echo $check_sg

    check_sg=$( echo "$check_sg" | grep -oP '(?<="GroupId": ")[^"]*' | uniq) 
    echo $check_sg

    if [ "$check_sg" == "" ]; then
        echo "Status: Creating Security Group"

        sg_id=$(aws ec2 create-security-group --group-name ${env}-main-sg --vpc-id $vpc_id --description 'Main Security Group') 
        echo $sg_id

        sg_id=$(echo "$sg_id" | grep -oP '(?<="GroupId": ")[^"]*' | uniq)
        echo $sg_id
        if [ "$sg_id" == "" ]; then
            echo "Error While Creating Secuity Group"
            exit 1

        fi
        echo $sg_id

        for rule in "${RULES[@]}"; do
            rule=${rule/<new-security-group-id>/$sg_id}
            echo "Adding rule: $rule"
            Add_Rule_Output=$(aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions "$rule" 2>&1)
            if [  ]; then
                echo "Error While Adding Rule '$rule': $Add_Rule_Output"
                aws ec2 delete-security-group --group-id $sg_id
                exit 1
            fi
        done

    else
        echo "Security Group Already Exists"
        sg_id=$check_sg
        echo $sg_id
    fi
    echo "--------------"

}

describe_ec2_key
if [ "$check_ec2_key" == "" ]; then
    echo "key is not exists."
    echo "Create key and secret."
    create_ec2_key
    create_secret
else
    describe_secret
    if [ "$secret_arn" == "" ]; then
        echo "key exists but secret not exists."
        echo "Deleting everything then create new key and secret."
        delete_ec2_key
        create_ec2_key
        create_secret
    else
        echo "Nothing created. key and secret are already exists."
        echo "----------------"
    fi
fi

create_sg
