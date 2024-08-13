#!/bin/bash

vpc_name="${env}-devops90-vpc"

create_vpc(){
    check_vpc=$(aws ec2 describe-vpcs --region eu-west-2 --filters Name=tag:Name,Values=$vpc_name | grep -oP '(?<="VpcId": ")[^"]*')
    if [ "$check_vpc" == "" ]; then
        vpc_result=$(aws ec2 create-vpc \
        --cidr-block $network_cidr --region $region \
        --tag-specification ResourceType=vpc,Tags="[{Key=Name,Value=${vpc_name}}]" \
        --output json)
        echo $vpc_result
        vpc_id=$(echo $vpc_result | grep -oP '(?<="VpcId": ")[^"]*')
        echo $vpc_id
        if [ "$vpc_id" == "" ]; then
            echo "Error While Creating the VPC $vpc_name"
            exit 1
        fi

        echo "VPC Created"
    else 
        echo "VPC Already Exists"
        vpc_id=$check_vpc
        echo $vpc_id
    fi

}



create_internet_gateway(){
    igw_name="${env}-devops90-igw"

    check_igw=$(aws ec2 describe-internet-gateways  --filters Name=tag:Name,Values=${igw_name} | grep -oP '(?<="InternetGatewayId": ")[^"]*')
    # create internet gateway
    if [ "$check_igw" == "" ]; then
        echo "internet gateway will be created"

        igw_id=$(aws ec2 create-internet-gateway --region ${region} \
            --tag-specifications ResourceType=internet-gateway,Tags="[{Key=Name,Value=${igw_name}}]" --output json | grep -oP '(?<="InternetGatewayId": ")[^"]*')

        if [ "$igw_id" == "" ]; then
            echo "Error While Creating  Internet Gateway"
            exit 1
        fi
        echo "internet gateway created."
        
    else
        echo "internet gateway already exist"
        igw_id=$check_igw
    fi

    echo $igw_id
    

}


# Attach the internet gateway to vpc (no output)
attch_ig_to_vpc(){

    igw_attach=$(aws ec2 describe-internet-gateways --internet-gateway-ids $igw_id | grep -oP '(?<="VpcId": ")[^"]*')
    if [ "$igw_attach" != "$vpc_id" ]; then
        attach_result=$(aws ec2 attach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id)
        if [ "$attach_result" == "" ]; then
            echo "internet gateway attached to the vpc"
        else 
            echo "Internet gateway AlreadyAssociated"
        fi
    else
        echo "Internet gateway already attached to this vpc"
    fi
    echo "---------------------"    

}




create_public_route()
{
    # create public route 
    route_result=$(aws ec2 create-route --route-table-id $public_rtb_id \
        --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id )
    echo $route_result #{ "Return": true }

    route_result=$(echo "$route_result" | jq '.Return')
    echo $route_result
#{ "Return": true }

    if [ "$route_result" != "true" ]; then
        echo "Public Route Creation Failed"
        exit 1
    fi
    echo "Public Route Created"
}



create_public_route_table(){
    check_rtb=$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=${env}-public-devops90-rtb)

    public_rtb_id=$(echo "$check_rtb" | grep -oP '(?<="RouteTableId": ")[^"]*' | uniq)
    echo $public_rtb_id

    if [ "$public_rtb_id" == "" ]; then
        echo "Creating route table....!"
        public_rtb_id=$(aws ec2 create-route-table --vpc-id $vpc_id --tag-specifications ResourceType=route-table,Tags="[{Key=Name,Value=${env}-public-devops90-rtb}]"  --output json | grep -oP '(?<="RouteTableId": ")[^"]*'  | uniq)
        if [ "$public_rtb_id" == "" ]; then
            echo "Error in create public route table"
            exit 1
        fi
        echo "public route table created."
        
        create_public_route

    else
        echo "public route table already exist" 
        
        rtb_route=$(echo $check_rtb | grep -oP '"DestinationCidrBlock"\s*:\s*"0.0.0.0/0"')
        if [ "$rtb_route" == "" ]; then
            create_public_route
        else
            echo "public route already exist"
        fi

    fi

    echo $public_rtb_id
    echo "----------------"

}

#---------------------------------------------------

# create private route table
create_private_route_table()
{
    check_rtb=$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=${env}-private-devops90-rtb | grep -oP '(?<="RouteTableId": ")[^"]*' | uniq)
    if [ "$check_rtb" == "" ]; then
        echo "Pivate Route Table will be created"
        private_rtb_id=$(aws ec2 create-route-table --vpc-id $vpc_id --tag-specifications ResourceType=route-table,Tags="[{Key=Name,Value=${env}-private-devops90-rtb}]"  --output json | grep -oP '(?<="RouteTableId": ")[^"]*'  | uniq)

        if [ "$private_rtb_id" == "" ]; then
            echo "Error While Creating Private Route Table"
            exit 1
        fi
        echo "Pivate Route Table Created."

    else
        echo "Private Route Table Already Exists"
        private_rtb_id=$check_rtb

    fi
    
    echo $private_rtb_id
    echo "--------------"

}


create_subnet()
{   
    # $1 subnet cidr, $2 az, $3 public or private
    check_subnet=$(aws ec2 describe-subnets --region $region --filters Name=tag:Name,Values=${env}-sub-$3-$1 | grep -oP '(?<="SubnetId": ")[^"]*')
    if [ "$check_subnet" == "" ]; then

        echo "subnet $1 will be created"

        subnet_result=$(aws ec2 create-subnet \
        --vpc-id $vpc_id --availability-zone ${region}$2 \
        --cidr-block $1 \
        --tag-specifications ResourceType=subnet,Tags="[{Key=Name,Value=${env}-sub-$3-$1}]" --output json)
        
        echo $subnet_result

        subnet_id=$(echo $subnet_result | grep -oP '(?<="SubnetId": ")[^"]*')
        echo $subnet_id

        if [ "$subnet_id" == "" ]; then
            echo "Error in create subnet $1"
            exit 1
        fi
        echo "subnet $1 created."

    else
        echo "subnet $1 already exist"
        subnet_id=$check_subnet
        echo $subnet_id

    fi
    echo "----------------"

}


create_vpc
create_internet_gateway
attch_ig_to_vpc
create_public_route_table
create_private_route_table


for sub in "${public_subnets[@]}"; do
    readarray -d "," -t sub_array <<< "$sub"
    create_subnet ${sub_array[0]} ${sub_array[1]} public
    # associate public route table to the private subnets
    aws ec2 associate-route-table --route-table-id $public_rtb_id --subnet-id $subnet_id
done


for sub in "${private_subnets[@]}"; do
    readarray -d "," -t sub_array <<< "$sub"
    create_subnet ${sub_array[0]} ${sub_array[1]} private
    # associate private route table to the private subnets
    aws ec2 associate-route-table --route-table-id $private_rtb_id --subnet-id $subnet_id
done
