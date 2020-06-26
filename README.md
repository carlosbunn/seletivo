## Questão 1


Essa primeira questão é bem genérica, e varios fatores da aplicação, a forma da qual ela é provida, e o tipo de acesso que temos disponível ao ftp resultaria em métodos diferenciados.

Por exemplo, a aplicação requer 100% uptime? Caso positivo seria interessante seguir para um "blue-green deployment" onde se mantém a aplicação antiga rodando, e faz-se o deploy em outra instância. Após a checagem de uma condição de sucesso da aplicação (teste de um conteudo da aplicação, ou mensagem de sucesso no log, depende do caso) poderíamos trocar uma configuração de um NGINX que repassa a conexão, para apontar para o novo deploy. depois do teste de sucesso externo, o deploy mais antigo pode ser destruído.

Outros fatores que devem ser considerados são dados da aplicação, se ela acessa um banco de dados, se é prudente fazer um backup caso o banco também sofra alteração, e qual o plano para reverter a alteração desse banco em caso de emergência.

Também como a aplicação é fornecida, a questão informa que é um FTP, mas dependendo do desenvolvedor o processo involve checar a partir de um certo horário de deploy, checar em periodos regulares, buscar o jar em uma pasta "Latest", o que faria necessário testar o arquivo por mudanças. Eu prefiro checar crc de um arquivo, mas dependendo do tamanho da aplicação pode não ser viável. Uma checagem de data de arquivo, seria razoavelmente segura para definir que a versão foi alterada, caso não houvesse nenhuma outra dica (arquivo com versão, ou incremento da pasta de versão). Isso tornaria possível testar se o arquivo é novo, sem a necessidade de transferir todos os dados.


Assumindo uma aplicação simples, sem banco de dados, onde o objetivo seja apenas rodar o proximo jar, e assumindo uma aplicação web eu seguiria os seguintes passos:

* Testar se existe um arquivo novo para deploy a cada X minutos, sendo esse o tempo concordado com o cliente

* Caso o arquivo esteja presente, fazer o download do jar para uma pasta nomeada com a data e hora para facilitar a identificação (Ex 2020-06-20-13). Caso necessário renomear o arquivo para o mesmo nome do aplicativo em produção. 

*Adicionar o sha256sum do aplicativo em uma lista, para que não ocorra erro de re-deploy do mesmo arquivo, caso a data dele mude por qualquer motivo. Essa lista deve ser testada sempre que um download seja feito, e o script pode parar caso encontre a string

* Rodar um container para testar a aplicação, onde o volume aponta para a pasta 020-06-20-13. O container roda o java -jar <app.jar>. Eu alternaria a porta exposta do container entre duas opções, basta testar qual porta está em vigor em produção no momento e usar a outra para subir o container mais recente (Ex. 8181 e 8282)

* Testar se a pagina da aplicação, ou API está presente, isso pode ser feito com curl, testando uma string fixa que indique que a aplicação subiu com sucesso. Caso esse passo falhe, o script deverá alertar a equipe por e-mail, ou qualquer aplicação preferida, e parar nesse ponto.

* Caso todos os testes passem, a configuração do NGINX pode ser trocada para apontar para o novo container, e então seria feito o reload do NGINX. O container anterior pode ser parado, mas seria mantido por algum tempo no sistema para que possa ser reativado caso necessário.

Todos esses passos devem ser logados e enviados para um local centralizador (e-mail, logstash) para que possam ser revisados em caso de problema.

Reiterando que essa é uma solução genérica. Caso a empresa use Jenkins, eu aplicaria uma solução em Jenkins, ou GoCD, ou o que mais se adequasse ao sistema que já existe, pois manter a conformidade facilita muito o controle da operação.

## Questão 2



## Questão 3

```
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
```

