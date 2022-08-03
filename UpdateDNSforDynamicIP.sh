#!/bin/bash

## BASIC INFORMATION
EMAIL='your-email-address-on-cloud-flare'
DOMAIN='example.com'
ACCOUNT_ID='account-id-on-cloudflare' #https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/find-account-and-zone-ids/

URI='https://api.cloudflare.com/client/v4/zones'
CTYPE='Content-Type:application/json'

## CURRENT WAN IP FROM ISP
## Uncomment this line if you want to test the script. Don't forget to comment next line
WAN_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

## ZONE_ID FOR TOP LEVEL DOMAIN
ZONE_ID=$(curl -s -X GET "$URI/?name=$DOMAIN&status=active&account.id=$ACCOUNT_ID&account.name=$EMAIL" \
          -H "Authorization: Bearer $BEARER_TOKEN" \
          -H "$CTYPE" | jq '.result[] | "\(.id)"' | \
           cut -c 2- | rev | cut -c 2- | rev)

## PROXIED RECORDS ARRAY

PR_RECORD=$(curl -s -X GET "$URI/$ZONE_ID/dns_records?type=A&proxied=true" \
            -H "Authorization: Bearer $BEARER_TOKEN" \
            -H "$CTYPE" | jq '.result[] | "\(.name)"' | \
             cut -c 2-  | rev | cut -c 2- | rev)

## DNS RECORDS ( NO PROXY CONFIGURED )
DNS_RECORD="$(curl -s -X GET "$URI/$ZONE_ID/dns_records?type=A&proxied=false" \
              -H "Authorization: Bearer $BEARER_TOKEN" \
              -H "$CTYPE" | jq '.result[] | "\(.name)"' | \
               cut -c 2-  | rev | cut -c 2- | rev)"

#### - FUNCTION TO UPDATE DNS IP ADDRESS - ####

update_dns_ip () {

  CLFL_IP=$(curl -s -X GET "$URI/$ZONE_ID/dns_records?name=$1" \
            -H "Authorization: Bearer $BEARER_TOKEN" \
            -H "$CTYPE" | jq '.result[] | "\(.content)"' | cut -c 2- | rev | cut -c 2- | rev)

  DNS_RECORD_ID=$(curl -s -X GET "$URI/$ZONE_ID/dns_records?name=$1" \
                  -H "Authorization: Bearer $BEARER_TOKEN" \
                  -H "$CTYPE" | jq '.result[] | "\(.id)"' | cut -c 2- | rev | cut -c 2- | rev)

  if [ "$WAN_IP" != "$CLFL_IP" ]; then
    curl -X PUT "$URI/$ZONE_ID/dns_records/$DNS_RECORD_ID" \
      -H "Authorization: Bearer $BEARER_TOKEN" \
      -H "$CTYPE" \
      --data '{"type":"A","name":"'"$1"'","content":"'"$WAN_IP"'","ttl":3600,"proxied":'"$2"'}' 2>/dev/null
  fi
}

#### - END FUNCTION - ####

for i in ${DNS_RECORD[@]}; do
  update_dns_ip $i false
done

for i in ${PR_RECORD[@]}; do
  update_dns_ip $i true
done

