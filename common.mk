CF_TOKEN:=$(shell hcp vault-secrets run --app=Packer -- env | grep CLOUDFLARE_TERRAFORM_KUNDUN_APITOKEN | sed -e s/CLOUDFLARE_TERRAFORM_KUNDUN_APITOKEN=//)

export TF_VAR_api_token_secret=${CF_TOKEN}



