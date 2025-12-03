FROM chatwoot/chatwoot:v4.8.0

# Instala Node.js, npm e pnpm no Alpine
RUN apk add --no-cache nodejs npm && \
    npm install -g pnpm@10

# 0 - Atualiza a versão exibida no rodapé do Chatwoot
RUN sed -i '54i\      <span class="px-2">0.12.2</span>' app/javascript/dashboard/routes/dashboard/settings/account/components/BuildInfo.vue

# 1 -- Ocultar conversas atruibuidas para agentes não-admin ---
RUN sed -i "48c\      'administrator'," app/javascript/dashboard/constants/permissions.js

# 2 - Remover botão delete das mensagens
RUN sed -i "356,359c\   delete:false," app/javascript/dashboard/components-next/message/Message.vue

# 3 - Bloquear criação de novas conversas para contatos com conversas abertas
# Impede que agentes criem múltiplas conversas com o mesmo contato.
# Quando um contato já possui uma conversa OPEN ou PENDING, retorna erro 422
# com mensagem informando o ID da conversa existente.
RUN sed -i 's/look_up_exising_conversation || create_new_conversation/look_up_exising_conversation || block_if_open_conversation || create_new_conversation/' app/builders/conversation_builder.rb && \
    sed -i '/def look_up_exising_conversation/i\  def block_if_open_conversation\n    open_conversation = @contact_inbox.contact.conversations\n                          .where(status: [:open])\n                          .first\n    return nil unless open_conversation\n\n    conversation = Conversation.new\n    conversation.errors.add(:base, "Contato já possui uma conversa aberta ##{open_conversation.display_id}")\n    raise ActiveRecord::RecordInvalid.new(conversation)\n  end\n\n' app/builders/conversation_builder.rb && \
    sed -i 's/throw new Error(error);/throw error?.response?.data?.message ? new Error(error.response.data.message) : new Error(error);/' app/javascript/dashboard/store/modules/contactConversations.js && \
    sed -i 's/error instanceof ExceptionWithMessage/error?.message \&\& error.message !== "Error"/' app/javascript/dashboard/components-next/NewConversation/ComposeConversation.vue && \
    sed -i 's/? error.data/? error.message/' app/javascript/dashboard/components-next/NewConversation/ComposeConversation.vue

# 5 --- Ocultar menus para o Agent ---
# 1. Adiciona o import do useAdmin antes da definição de props.
# 2. Insere a variável isAdmin após o import do useAdmin.
# 3. Injeta a função filteredMenuItems antes do </script>, incluindo lógica de filtro
#    que oculta itens como Portals, Captain e Settings para usuários que não são admin.
# 4. Substitui o v-for original (menuItems) para usar o novo filteredMenuItems.
# ----------------------------------------------------------
RUN sed -i "/const props/i import { useAdmin } from 'dashboard/composables/useAdmin';" app/javascript/dashboard/components-next/sidebar/Sidebar.vue && \
    sed -i "/import { useAdmin }/a const { isAdmin } = useAdmin();" app/javascript/dashboard/components-next/sidebar/Sidebar.vue && \
    sed -i "/<\/script>/i const filteredMenuItems = computed(() => {\n  if (isAdmin.value) {\n    return menuItems.value;\n  }\n  return isAdmin.value ? menuItems.value : menuItems.value.filter(item => \!['Portals', 'Captain', 'Settings', 'Inbox'].includes(item.name));\n});" app/javascript/dashboard/components-next/sidebar/Sidebar.vue && \
    sed -i "s/v-for=\"item in menuItems\"/v-for=\"item in filteredMenuItems\"/" app/javascript/dashboard/components-next/sidebar/Sidebar.vue

# 6 - Adiciona o callback normalize_phone_number e insere o método no model Contact
# para normalizar números de telefone antes da validação.
RUN sed -i '/before_validation :prepare_contact_attributes/a\  before_validation :normalize_phone_number' app/models/contact.rb && \
    sed -i '/def phone_number_format/i\  def normalize_phone_number\n    return if phone_number.blank?\n\n    # Remove caracteres não numéricos exceto +\n    cleaned = phone_number.gsub(/[^\\d+]/, "")\n\n    # Se for número brasileiro com 12 dígitos (sem o 9), adiciona o 9 após o DDD\n    if cleaned.match?(/\\+55\\d{10}\\z/)\n      cleaned = cleaned.insert(5, "9")\n    end\n\n    self.phone_number = cleaned\n  end\n' app/models/contact.rb

# 7 - Adiciona funcionalidade de reatribuição automática ao resolver conversas
# Modifica o concern AutoAssignmentHandler para incluir um novo after_save
# que aciona a reatribuição automática quando uma conversa é marcada como resolvida.    
RUN sed -i '/after_save :run_auto_assignment/a\    after_save :trigger_reassignment_on_resolve' app/models/concerns/auto_assignment_handler.rb && \
    sed -i '/^end$/i\  def trigger_reassignment_on_resolve\n    return unless saved_change_to_status? \&\& resolved?\n    return unless inbox.enable_auto_assignment?\n    if inbox.auto_assignment_v2_enabled?\n      AutoAssignment::AssignmentJob.perform_later(inbox_id: inbox.id)\n    else\n      unassigned = inbox.conversations.unassigned.open.where.not(id: id).order(:created_at).first\n      return unless unassigned\n      AutoAssignment::AgentAssignmentService.new(conversation: unassigned, allowed_agent_ids: inbox.member_ids_with_assignment_capacity).perform\n    end\n  end\n' app/models/concerns/auto_assignment_handler.rb

# Precompila os assets com uma SECRET_KEY_BASE fake
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile
