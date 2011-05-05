module MongoidSphinx
  module Delta
    extend ActiveSupport::Concern
    included do
      after_save :update_index
      after_save :index_delta
    end
    
    def index_delta
      config = MongoidSphinx::Configuration.instance
      rotate = MongoidSphinx.sphinx_running? ? "--rotate" : ""
      
      output = `#{config.bin_path}#{config.indexer_binary_name} --config "#{config.config_file}" #{rotate} #{model.sphinx_index.delta_name.join(' ')}`      
    end
    
    def update_indeces      
      attrs = self.changes.select do |key, value|
        self.search_fields.include?(key) || self.search_attributes.include?(key)
      end
      
      attribute_names = attrs.keys.collect{|key| key.to_s}
      
      # Prepare attributes for indexing
      self.search_attributes.each do |key, value|
        case value.class
        when Hash
          entries = []
          self.document_hash[key.to_s].to_a.each do |entry|                    
            entries << entry.join(" : ")
          end
          attrs[key] = entries.join(", ")
        when Array
          attrs[key] = self.document_hash[key.to_s].join(", ")
        when Date
          attrs[key] = self.document_hash[key.to_s].to_time.to_i
        when DateTime || Time
          attrs[key] = self.document_hash[key.to_s].to_i
        when Boolean
          attrs[key] = self.document_hash[key.to_s] ? 1 : 0
        else
          attrs[key] = self.document_hash[key.to_s].to_s
        end
      end
      
      # Prepare fields for indexing
      self.search_fields.each do |key|
        if document_hash[key.to_s].is_a?(Array)
          attrs[key] = "<#{key}><![CDATA[[#{document_hash[key.to_s].join(", ")}]]></#{key}>"                
        elsif document_hash[key.to_s].is_a?(Hash)
          entries = []
          document_hash[key.to_s].to_a.each do |entry|                    
            entries << entry.join(" : ")
          end
          attrs[key] = "<#{key}><![CDATA[[#{entries.join(", ")}]]></#{key}>"
        else
          attrs[key] = "<#{key}><![CDATA[[#{document_hash[key.to_s]}]]></#{key}>"
        end
      end
      
      attribute_values = attrs.values
      # Update core first (update existing records)
      update_index self.class.sphinx_index.core_name, attribute_names, attribute_values
      # Update delta (new records)
      update_index self.class.sphinx_index.delta_name, attribute_names, attribute_values
    end
    
    def update_index(index_name, attribute_names, attribute_values)
        client = MongoidSphinx::Configuration.instance.client
        if self.class.seach_ids(self.sphinx_id..self.sphinx_id, :index => index_name,:raw => true)
          client.update index_name, attribute_names, {self.sphinx_id => attribute_values} 
        end
    end    
  end
end