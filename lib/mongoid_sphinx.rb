require "mongoid"
require "riddle"

require 'mongoid_sphinx/configuration'
require 'mongoid_sphinx/context'
require 'mongoid_sphinx/index'
require 'mongoid_sphinx/mongoid/identity'
require 'mongoid_sphinx/mongoid/sphinx'
require 'mongoid_sphinx/railtie'

module MongoidSphinx
  
  @@sphinx_mutex = Mutex.new
  @@context      = nil
  
  def self.context
    if @@context.nil?
      @@sphinx_mutex.synchronize do
        if @@context.nil?
          @@context = MongoidSphinx::Context.new
          @@context.prepare
        end
      end
    end
    
    @@context
  end
  
  def self.reset_context!
    @@sphinx_mutex.synchronize do
      @@context = nil
    end
  end
  
  def self.sphinx_running?
    !!sphinx_pid && pid_active?(sphinx_pid)
  end
  
  def self.sphinx_pid
    if File.exists?(MongoidSphinx::Configuration.instance.pid_file)
      File.read(MongoidSphinx::Configuration.instance.pid_file)[/\d+/]
    else
      nil
    end
  end
  
end