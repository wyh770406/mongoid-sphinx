module Mongoid
  class Identity
    
    protected
      
      # Return an id that is sphinx compatible
      def generate_id
        limit = (1 << 64) - 1
      
        while true
          id = rand(limit)
          candidate = "#{@document.class.to_s}-#{id}"
        
          begin
            @document.class.find(candidate) # Resource not found exception if available
          rescue Mongoid::Errors::DocumentNotFound
            id = BSON::ObjectId.from_string(candidate)
            @document.using_object_ids? ? id : id.to_s
            break
          end
        end
      end
    
  end
end