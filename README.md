# integracoes-docker


## Prepare the database
docker-compose run --rm rails bundle exec rails db:chatwoot_prepare

## Migrate
docker exec -it chatwoot bundle exec rails db:migrate

admin@mail.com  
Admin@2000

## Criar docker image
docker build -t lucassousaweb/chatwoot:v4.8.0 .

docker login

docker push lucassousaweb/chatwoot:v4.8.0
