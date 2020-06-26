#!/bin/bash

#Script de teste de status do json do webservice
#Por Carlos Bunn 22/06/2020

#Uso: testjson.sh <website> <e-mail>
#Exemplo: testjson.sh localhost/status.json root@vultr.guest

website="$1"
email="$2"

#Testa se o software necessario para enviar e-mails está no sistema
command -v sendmail > /dev/null
if [ $? -ne 0 ]; then
	echo "Esse script necessita do binario sendmail"
	exit 1
fi

#cria arquivo temporario na pasta tmp default do sistema
status=$(mktemp)

#funcao de envio de email
function send_email {
	message=$(mktemp)
	echo "Subject: ALERTA - Sistema fora do ar em $HOSTNAME " > $message
	echo "" >> $message
	echo "Os seguintes servicos falharam:" >> "$message"
	cat "$status" >> "$message"
	sendmail "$email" < "$message"
	rm "$message"
}

#testa se o site esta acessivel, se não envia alerta
curl -s localhost/status.json >> /dev/null

if [ $? -ne 0 ]; then
	echo "Arquivo json não está acessivel" > "$status"
	send_email
	rm "$status"
	exit 0
fi

#Faz o teste do site e procura pela palavra "down". Caso positivo envia a mensagem usando a função de e-mail

curl -s "$website"|grep down > "$status" && send_email

rm "$status"
exit 0

