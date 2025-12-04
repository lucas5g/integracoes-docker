# 6 - Adiciona o callback normalize_phone_number e insere o método no model Contact
# para normalizar números de telefone antes da validação.
RUN sed -i '/before_validation :prepare_contact_attributes/a\  before_validation :normalize_phone_number' app/models/contact.rb && \
    sed -i '/def phone_number_format/i\  def normalize_phone_number\n    return if phone_number.blank?\n\n    # Remove caracteres não numéricos exceto +\n    cleaned = phone_number.gsub(/[^\\d+]/, "")\n\n    # Se for número brasileiro com 12 dígitos (sem o 9), adiciona o 9 após o DDD\n    if cleaned.match?(/\\+55\\d{10}\\z/)\n      cleaned = cleaned.insert(5, "9")\n    end\n\n    self.phone_number = cleaned\n  end\n' app/models/contact.rb
