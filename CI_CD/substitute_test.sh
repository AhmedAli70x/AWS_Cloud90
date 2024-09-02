public_subnets=(
    "10.0.1.0/24,a"
    "10.0.2.0/24,b"
    "<new_ip>"
)
public_subnets_string="${public_subnets[@]}"
echo $public_subnets_string
vpc_ip="123.123.123.123"
# sub="${public_subnets[2]}"
echo $sub
public_subnets_string=${public_subnets_string//"<new_ip>"/${vpc_ip}}

IFS=' ' read -r -a public_subnets <<< "$public_subnets_string"
echo "${public_subnets[@]}"

