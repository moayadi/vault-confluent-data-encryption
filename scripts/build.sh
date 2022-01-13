docker build -t app:latest -f ../app/Dockerfile ../app
docker build -t transform:latest -f ../transform/Dockerfile ../transform
docker build -t fluentd:latest -f ../fluentd/Dockerfile ../fluentd

docker tag app:latest moayadi/vault-confluentcloud-demo:app-latest
docker tag transform:latest moayadi/vault-confluentcloud-demo:transform-latest
docker tag fluentd:latest moayadi/vault-confluentcloud-demo:fluentd-latest

docker push moayadi/vault-confluentcloud-demo:app-latest
docker push moayadi/vault-confluentcloud-demo:transform-latest
docker push moayadi/vault-confluentcloud-demo:fluentd-latest
