# MongoidSphinx

## Fork info

This is a fork of http://github.com/burke/mongosphinx with many changes to simplify and support Mongoid.

## General info

The MongoidSphinx library implements an interface between MongoDB and Sphinx 
supporting Mongoid to automatically index objects in Sphinx. It tries to
act as transparent as possible: Just an additional method in Mongoid
and some Sphinx configuration are needed to get going.

## Prerequisites

MongoidSphinx needs gems Mongoid and Riddle as well as a running Sphinx
and a MongoDB installation. Just add this to your Gemfile:

    gem riddle
    gem mongoid
    gem mongoidsphinx, :require => 'mongoid_sphinx'

No additional configuraton is needed for interfacing with MongoDB: Setup is
done when Mongoid is able to talk to the MongoDB server.

A proper "sphinx.conf" file and a script for retrieving index data have to
be provided for interfacing with Sphinx: Sorry, no ThinkingSphinx like
magic... :-) Depending on the amount of data, more than one index may be used
and indexes may be consolidated from time to time.

This is a sample configuration for a single "main" index:

    searchd {
      address = 0.0.0.0
      port = 3312

      log = ./sphinx/searchd.log
      query_log = ./sphinx/query.log
      pid_file = ./sphinx/searchd.pid
    }

    source mongoblog {
      type = xmlpipe2
  
      xmlpipe_command = rake sphinx:genxml --silent
    }

    index mongoblog {
      source = mongoblog

      charset_type = utf-8
      path = ./sphinx/sphinx_index_main
    }

Notice the line "xmlpipe_command =". This is what the indexer runs to generate 
its input. You can change this to whatever works best for you, but I set it up as 
a rake task, with the following in `lib/tasks/sphinx.rake` .

Here :fields is a list of fields to export. Performance tends to suffer if you export
everything, so you'll probably want to just list the fields you're indexing.

    namespace :sphinx do
      task :genxml => :environment do
        MongoidSphinx::Indexer::XMLDocset.stream(Food)
      end
    end

This uses MongoDB cursor to better stream collection. Instead of offset. See: http://groups.google.com/group/mongodb-user/browse_thread/thread/35f01db45ea3b0bd/96ebc49b511a6b41?lnk=gst&q=skip#96ebc49b511a6b41

## Models

Use method _search_index_ to enable indexing of a model. You must provide a list of
attribute keys.

A side effect of calling this method is, that MongoidSphinx overrides the
default of letting MongoDB create new IDs: Sphinx only allows numeric IDs and
MongoidSphinx forces new objects with the name of the class, a hyphen and an
integer as ID (e.g. _Post-38497238_). Again: Only these objects are
indexed due to internal restrictions of Sphinx.

Sample:

    class Post
      include Mongoid::Sphinx

      field :title
      field :body
      field :created_at, :type => 'DateTime'
      field :comment_count, :type => 'Integer'

      search_index(:fields => [:title, :body], :attributes => [:created_at, :comment_count])
    end

You must also create a config/sphinx.yml file with the host and port of your sphinxd process like so:

    development:
      address: localhost
      port: 3312
      
    staging:
      address: localhost
      port: 3312
      
    production:
      address: localhost
      port: 3312

## Queries

An additional instance method <tt>search</tt> is added for each
search indexed model. This method takes a Sphinx query like
`foo @title bar`, runs it within the context of the current class and returns
an Array of matching MongoDB documents.

Samples:

    Post.search('first')
    => [...]
    
    post = Post.search('this is @title post').first
    post.title
    => "First Post"
    post.class
    => Post

Additional options _:match_mode_, _:limit_ and
_:max_matches_ can be provided to customize the behavior of Riddle.
Option _:raw_ can be set to _true_ to do no lookup of the
document IDs but return the raw IDs instead.

Sample:

    Post.search('my post', :limit => 100)
    
You can also specify filters based on attributes. Here is the format:

    post = Post.search('first', :with => {:created_at => 1.day.ago..Time.now})
    post = Post.search('first', :without => {:created_at => 1.day.ago..Time.now})
    post = Post.search('first', :with => {:comment_count => [5,6]})

## Copyright

Copyright (c) 2010 RedBeard Tech. See LICENSE for details.
