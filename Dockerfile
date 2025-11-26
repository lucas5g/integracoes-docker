FROM chatwoot/chatwoot:v4.8.0

# Instala Node.js, npm e pnpm no Alpine
RUN apk add --no-cache nodejs npm && \
    npm install -g pnpm@10

# Customizações no projeto
RUN sed -i "40s/\.\.\.ROLES/'administrator'/g" app/javascript/dashboard/constants/permissions.js && \
    sed -i "48s/\.\.\.ROLES/'administrator'/g" app/javascript/dashboard/constants/permissions.js

# Remover botão delete das mensagens
RUN sed -i "356,359c\   delete:false," app/javascript/dashboard/components-next/message/Message.vue

# =============================================================================
# PATCH: Bloquear criação de novas conversas para contatos com conversas abertas
# Impede que agentes criem múltiplas conversas com o mesmo contato.
# Quando um contato já possui uma conversa OPEN ou PENDING, retorna erro 422
# com mensagem informando o ID da conversa existente.
# =============================================================================
RUN sed -i 's/look_up_exising_conversation || create_new_conversation/look_up_exising_conversation || block_if_open_conversation || create_new_conversation/' app/builders/conversation_builder.rb && \
    sed -i '/def look_up_exising_conversation/i\  def block_if_open_conversation\n    open_conversation = @contact_inbox.contact.conversations\n                          .where(status: [:open, :pending])\n                          .first\n    return nil unless open_conversation\n\n    conversation = Conversation.new\n    conversation.errors.add(:base, "Contato já possui uma conversa aberta ##{open_conversation.display_id}")\n    raise ActiveRecord::RecordInvalid.new(conversation)\n  end\n\n' app/builders/conversation_builder.rb && \
    sed -i 's/throw new Error(error);/throw error?.response?.data?.message ? new Error(error.response.data.message) : new Error(error);/' app/javascript/dashboard/store/modules/contactConversations.js && \
    sed -i 's/error instanceof ExceptionWithMessage/error?.message \&\& error.message !== "Error"/' app/javascript/dashboard/components-next/NewConversation/ComposeConversation.vue && \
    sed -i 's/? error.data/? error.message/' app/javascript/dashboard/components-next/NewConversation/ComposeConversation.vue


# Precompila os assets com uma SECRET_KEY_BASE fake
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile
