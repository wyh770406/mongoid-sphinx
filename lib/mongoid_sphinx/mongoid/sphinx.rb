# MongoidSphinx, a full text indexing extension for MongoDB/Mongoid using
# Sphinx.

module Mongoid
  module Sphinx
    extend ActiveSupport::Concern
    included do
      SPHINX_TYPE_MAPPING = {
        'Date' => 'timestamp',
        'DateTime' => 'timestamp',
        'Time' => 'timestamp',
        'Float' => 'float',
        'Integer' => 'uint',
        'BigDecimal' => 'float',
        'Boolean' => 'bool'
      }
      
      cattr_accessor :search_fields
      cattr_accessor :search_attributes
    end
    
    module ClassMethods
      def search_index(options={})
        self.search_fields = options[:fields]
        self.search_attributes = {}
        options[:attributes].each do |attrib|
          self.search_attributes[attrib] = SPHINX_TYPE_MAPPING[self.fields[attrib.to_s].type.to_s] || 'string'
        end
      end
      
      def sphinx_stream
        STDOUT.sync = true # Make sure we really stream..
        
        puts '<?xml version="1.0" encoding="utf-8"?>'
        puts '<sphinx:docset>'
        
        # Schema
        puts '<sphinx:schema>'
        self.search_fields.each do |key, value|
          puts "<sphinx:field name=\"#{key}\"/>"
        end
        self.search_attributes.each do |key, value|
          puts "<sphinx:attr name=\"#{key}\" type=\"#{value}\"/>"
        end
        # FIXME: What is this attribute?
        puts '<sphinx:field name="classname"/>'
        puts '<sphinx:attr name="csphinx-class" type="multi"/>'
        puts '</sphinx:schema>'
        
        self.find.each do |document_hash|
          sphinx_compatible_id = document_hash['_id'].to_s.to_i - 100000000000000000000000
          
          puts "<sphinx:document id=\"#{sphinx_compatible_id}\">"
          # FIXME: Should we include this?
          puts '<csphinx-class>'
          puts MongoidSphinx::MultiAttribute.encode(self.to_s)
          puts '</csphinx-class>'
          puts "<classname>#{self.to_s}</classname>"
          
          self.search_fields.each do |key|
            puts "<#{key}><![CDATA[[#{document_hash[key.to_s]}]]></#{key}>"
          end
          self.search_attributes.each do |key, value|
            value = case value
              when 'bool' : document_hash[key.to_s] ? 1 : 0
              when 'timestamp' : document_hash[key.to_s].to_i
              else document_hash[key.to_s].to_s
            end 
            puts "<#{key}><![CDATA[[#{value}]]></#{key}>"
          end
          
          puts '</sphinx:document>'
        end
        
        puts '</sphinx:docset>'
      end
      
      def search(query, options = {})
        client = MongoidSphinx::Configuration.instance.client
                 
        query = query + " @classname #{self.to_s}"
        
        client.match_mode = options[:match_mode] || :extended
        client.limit = options[:limit] if options.key?(:limit)
        client.max_matches = options[:max_matches] if options.key?(:max_matches)
        
        if options.key?(:sort_by)
          client.sort_mode = :extended
          client.sort_by = options[:sort_by]
        end
        
        if options.key?(:with)
          options[:with].each do |key, value|
            client.filters << Riddle::Client::Filter.new(key.to_s, value, false)
          end
        end
        
        if options.key?(:without)
          options[:without].each do |key, value|
            client.filters << Riddle::Client::Filter.new(key.to_s, value, true)
          end
        end
        
        result = client.query(query)
        
        if result and result[:status] == 0 and (matches = result[:matches])
          classname = nil
          ids = matches.collect do |row|
            classname = MongoidSphinx::MultiAttribute.decode(row[:attributes]['csphinx-class'])
            (100000000000000000000000 + row[:doc]).to_s rescue nil
          end.compact
          
          return ids if options[:raw] or ids.empty?
          return Object.const_get(classname).find(ids)
        else
          return []
        end
      end
    end
    
  end
end
