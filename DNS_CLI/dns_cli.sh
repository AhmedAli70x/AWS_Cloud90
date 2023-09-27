region="eu-west-2"
dns_name="ahmediteng.com"

create_hosted_zone(){

    # check_hz=$(aws route53 list-hosted-zones --query "HostedZones[?Name == '$1']" | grep -oP '(?<="Id": ")[^"]*' | uniq )

    check_hz_id=$(aws route53 list-hosted-zones-by-name --dns-name $1 | grep -oP '(?<="Id": ")[^"]*' | uniq )
    echo $check_hz_id


    if [ "$check_hz_id" == "" ]; then

        echo "hosted Zone will be created"
        time=$(date -u +"%Y-%m-%d-%H-%M-%S")
        echo "time is $time"
        echo "hosted Zone will be created"

        hz_id=$( aws route53 create-hosted-zone --name $dns_name --caller-reference $time | grep -oP '(?<="Id": ")[^"]*' | uniq)

        if ["$hz_id" == ""]; then 
        
         echo "Erro increated Hosted Zone"
         exit 1

        fi
        echo "Hosted Zone created."

    else
        echo "Hosted Zone already exist."
        hz_id=$check_hz_id
    fi
}

create_hosted_zone $dns_name

get_ec2_ip(){


    ec2_ip=$(aws ec2 describe-instances --region $region --filters Name=tag:Name,Values=$1 Name=instance-state-name,Values=running | grep -oP '(?<="PublicIpAddress": ")[^"]*')

    if [ "$ec2_ip" == "" ]; then
    
        echo "EC2 with name $1 not available or not running"

    else

        echo "EC2 found. Public ip = $ec2_ip"



    fi
}

get_ec2_ip "RakionEc2"


create_dns_record(){

    sub_domain_name="$1.$dns_name"
    echo "Status: Listing DNS records"

    check_dns=$( aws route53 list-resource-record-sets --hosted-zone-id $hz_id --query "ResourceRecordSets[?Name == '$sub_domain_name.']" | grep -oP '(?<="Name": ")[^"]*')

    echo "check_dns: $check_dns"
    change=$(cat << EOF
{
"Changes": 
[
    {
    "Action": "CREATE",
    "ResourceRecordSet": 
    {
        "Name": "$sub_domain_name",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": 
        [
        {
            "Value": "$2"
        }
        ]
    }
    }
]
}
EOF
)

        change=$( echo $change | tr -d '\n' | tr -d ' ' )

    if [ "$check_record" == "" ]; then

        echo "DNS Record will be created..."
        record_id=$(aws route53 change-resource-record-sets --hosted-zone-id $hz_id  --change-batch $change | grep -oP '(?<="Id": ")[^"]*')

    else
        echo "Status: DNS Record exists."

    fi


}

create_dns_record srv2 $ec2_ip