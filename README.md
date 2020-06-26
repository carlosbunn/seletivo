## Questão 1


Essa primeira questão é bem genérica, e varios fatores da aplicação, a forma da qual ela é provida, e o tipo de acesso que temos disponível ao ftp resultaria em métodos diferenciados.

Por exemplo, a aplicação requer 100% uptime? Caso positivo seria interessante seguir para um "blue-green deployment" onde se mantém a aplicação antiga rodando, e faz-se o deploy em outra instância. Após a checagem de uma condição de sucesso da aplicação (teste de um conteudo da aplicação, ou mensagem de sucesso no log, depende do caso) poderíamos trocar uma configuração de um NGINX que repassa a conexão, para apontar para o novo deploy. depois do teste de sucesso externo, o deploy mais antigo pode ser destruído.

Outros fatores que devem ser considerados são dados da aplicação, se ela acessa um banco de dados, se é prudente fazer um backup caso o banco também sofra alteração, e qual o plano para reverter a alteração desse banco em caso de emergência.

Também como a aplicação é fornecida, a questão informa que é um FTP, mas dependendo do desenvolvedor o processo involve checar a partir de um certo horário de deploy, checar em periodos regulares, buscar o jar em uma pasta "Latest", o que faria necessário testar o arquivo por mudanças. Eu prefiro checar crc de um arquivo, mas dependendo do tamanho da aplicação pode não ser viável. Uma checagem de data de arquivo, seria razoavelmente segura para definir que a versão foi alterada, caso não houvesse nenhuma outra dica (arquivo com versão, ou incremento da pasta de versão). Isso tornaria possível testar se o arquivo é novo, sem a necessidade de transferir todos os dados.


Assumindo uma aplicação simples, sem banco de dados, onde o objetivo seja apenas rodar o proximo jar, e assumindo uma aplicação web eu seguiria os seguintes passos:

* Testar se existe um arquivo novo para deploy a cada X minutos, sendo esse o tempo concordado com o cliente

* Caso o arquivo esteja presente, fazer o download do jar para uma pasta nomeada com a data e hora para facilitar a identificação (Ex 2020-06-20-13). Caso necessário renomear o arquivo para o mesmo nome do aplicativo em produção. 

* Adicionar o sha256sum do aplicativo em uma lista, para que não ocorra erro de re-deploy do mesmo arquivo, caso a data dele mude por qualquer motivo. Essa lista deve ser testada sempre que um download seja feito, e o script pode parar caso encontre a string

* Rodar um container para testar a aplicação, onde o volume aponta para a pasta 020-06-20-13. O container roda o java -jar <app.jar>. Eu alternaria a porta exposta do container entre duas opções, basta testar qual porta está em vigor em produção no momento e usar a outra para subir o container mais recente (Ex. 8181 e 8282)

* Testar se a pagina da aplicação, ou API está presente, isso pode ser feito com curl, testando uma string fixa que indique que a aplicação subiu com sucesso. Caso esse passo falhe, o script deverá alertar a equipe por e-mail, ou qualquer aplicação preferida, e parar nesse ponto.

* Caso todos os testes passem, a configuração do NGINX pode ser trocada para apontar para o novo container, e então seria feito o reload do NGINX. O container anterior pode ser parado, mas seria mantido por algum tempo no sistema para que possa ser reativado caso necessário.

Todos esses passos devem ser logados e enviados para um local centralizador (e-mail, logstash) para que possam ser revisados em caso de problema.

Reiterando que essa é uma solução genérica. Caso a empresa use Jenkins, eu aplicaria uma solução em Jenkins, ou GoCD, ou o que mais se adequasse ao sistema que já existe, pois manter a conformidade facilita muito o controle da operação.

## Questão 2

Crie um laboratório e inicie uma instacia do minishift (​ https://github.com/minishift/minishift​ ),
após este passo faça neste minishift o deploy de um docker com nginx e faça ele prover
estaticamente um arquivo json com o seguinte conteúdo:

{"service": {"oracle": "ok", "redis": "ok", "mongo": "down", "pgsql": "down", "mysql": "ok"}}

Elabore uma documentação no estilo how-to para que outra pessoa possa replicar o seu
experimento.

----------------

### Instalação do minishift:

Host OS: CentOS 7

Primeiro instale as ferramentas de virtualização

```
yum install qemu-kvm libvirt libvirt-python libguestfs-tools virt-install
```

Caso o kvm apresente problemas, é possivel usar os drivers do virtualbox
Faça o download do pacote no site do virtualbox, e prepare o sistema antes da instalação:

```
yum install kernel-devel kernel-devel-3.10.0-1127.13.1.el7.x86_64 gcc make perl -y
```

Após as ferramentas do kernel serem instaladas, é possivel prosseguir com a instalação do virtualbox:

```
rpm -i VirtualBox-6.1-6.1.10_138449_el7-1.x86_64.rpm 

```

Depois podemos fazer a instalação do minishift:

```
wget https://github.com/minishift/minishift/releases/download/v1.34.2/minishift-1.34.2-linux-amd64.tgz
tar -zxvf minishift-1.34.2-linux-amd64.tgz 
mv minishift-1.34.2-linux-amd64/ /bin/
chmod 777 /bin/minishift 
```

Inicie o minishift:
```
minishift start
```
Caso esteja usando a versão do virtualbox, use o comando a seguir:

```
minishift start --vm-driver virtualbox
```

Após o start, pegue a url do console com 

```
minishift console --url
```

### Fazendo o deploy do container NGINX:

Nos meus testes eu fiz o deploy de duas formas diferentes. Primeiro alterando um container docker, depois alterando o repositório de um deploy de exemplo.

Modo 1:

Altere o NGINX que executa sem usuario root. Segue abaixo o dockerfile (também no repositório):

```
FROM nginxinc/nginx-unprivileged
USER root
RUN echo "{\"service\": {\"oracle\": \"ok\", \"redis\": \"ok\", \"mongo\": \"down\", \"pgsql\": \"down\", \"mysql\": \"ok\"}}"> /usr/share/nginx/html/status.json
RUN chown nginx:nginx /usr/share/nginx/html/status.json
USER nginx 
CMD ["/usr/sbin/nginx","-g","daemon off;"]
```

Faça o build do container executando na pasta do dockerfile

```
docker build .
```

Caso não o tenha feito ainda, execute o docker login e logue na sua conta do docker hub

Faça o commit e o push do container, utilizando o código da imagem gerado no commit

```
docker commit 5cc750d00e1a docker.io/carlosbunn/nginx.carlos
docker push docker.io/carlosbunn/nginx.carlos
```

A partir desse ponto podemos continuar no console web. O login padrão é admin/admin

Inicie um novo projeto em "Create Project"

Após clicar em create, abra o projeto, e clique em "Deploy Image". Preencha o campo com o repositório da sua imagem no docker hub

Nesse processo a rota não é criada por padrão, então clique no link "Create route". Pode-se usar as opções padrão.

Assim que o container terminar o deploy, o NGINX deverá estar acessivel na rota criada. O json de status está em /status.json

Modo 2:

Nesse modo podemos ir direto no catálogo e escolher o "Nginx HTTP server and reverse proxy (nginx)"

Eu fiz o clone do repositório de teste (https://github.com/sclorg/nginx-ex.git) e adicionei o arquivo json requerido pela questão no seguinte repositório: https://github.com/carlosbunn/nginx

Preencha com o repositório alterado no campo "Git repository" e inicie um novo projeto.

A URL de acesso já está na aba overview. Basta clicar no link e adicionar /status.json no final da URL.





## Questão 3

Crie um processo automático que lê o json publicado na questão anterior e gere um alerta via
e-mail de que este serviço não está disponível. Utilize a linguagem que preferir (Shell Script,
Python, Perl, Go, etc...).

Segue o script para fazer o teste abaixo (também no repositório)

O comando da crontab no meu caso seria o seguinte, imaginando que o script está em /usr/bin

```
2 * * * * /usr/bin/testjson.sh 'http://nginxcarlos-nginx-docker.192.168.99.100.nip.io/status.json' carlos.bunn@notmyrealmail.com >/dev/null 2>&1
```

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

