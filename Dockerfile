FROM chatwoot/chatwoot:latest

# Instala Node.js, npm e pnpm no Alpine
RUN apk add --no-cache nodejs npm && \
    npm install -g pnpm@10

# Customizações no projeto
RUN sed -i "40s/\.\.\.ROLES/'administrator'/g" app/javascript/dashboard/constants/permissions.js && \
    sed -i "48s/\.\.\.ROLES/'administrator'/g" app/javascript/dashboard/constants/permissions.js

# Remover botão delete das mensagensdelet
RUN sed -i "356,359c\   delete:false," app/javascript/dashboard/components-next/message/Message.vue

# Precompila os assets com uma SECRET_KEY_BASE fake
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile