# MongoSphinx, a full text indexing extension for using
# Sphinx.
#
# This file contains the includes implementing this library. Have a look at
# the README.rdoc as a starting point.

begin
  require 'rubygems'
rescue LoadError; end
require 'mongo_mapper'
require 'riddle'


module MongoSphinx
  if (match = __FILE__.match(/mongosphinx-([0-9.-]*)/))
    VERSION = match[1]
  else
    VERSION = 'unknown'
  end
end

require 'lib/multi_attribute'
require 'lib/indexer'
require 'lib/mixins/indexer'
require 'lib/mixins/properties'


# Include the Indexer mixin from the original Document class of
# MongoMapper which adds a few methods and allows calling method indexed_with.

module MongoMapper # :nodoc:
  module Document # :nodoc:
    include MongoMapper::Mixins::Indexer
    module InstanceMethods
      include MongoMapper::Mixins::Properties
    end
    module ClassMethods
      include MongoMapper::Mixins::Indexer::ClassMethods
    end
  end
end
