require 'mongo_mapper'

module Plucky
  class Query
    alias_method :find_without_sluggable, :find
    def find(*args)
      arg_f = args.first
      if (args.size == 1) && arg_f.is_a?(String) && ( arg_f !~ /^[0-9a-f]{24}$/i )
        fields = self.model.all_slug_fields
        record = nil
        fields.find do |options|
          conds = {}
          conds[options[:key]] = arg_f
          record = first( conds )
        end
        record
      else
        find_without_sluggable *args
      end
    end
  end
end

module MongoMapper
  module Plugins
    module Sluggable
      extend ActiveSupport::Concern

      module ClassMethods
        def sluggable(to_slug = :title, options = {})
          class_attribute :slug_options

          # this config determines how many slug fields there will be
          self.slug_options = {
            :to_slug      => to_slug,
            :key          => :slug,
            :locales      => nil,
            :index        => true,
            :method       => :parameterize,
            :scope        => nil,
            :max_length   => 256,
            :callback     => [:before_validation, {:on => :create}],
            :force        => false
          }.merge(options)

          # now define a slug key for all slugged fields
          slug_fields = all_slug_fields
          slug_fields.each do |field_options|
            key field_options[:key], String, :index => field_options[:index]
          end

          if slug_options[:callback].is_a?(Array)
            condition = slug_options[:callback][1]
            # accounting for a MongoMapper callback bug with validation callbacks that was fixed in 0.9.2
            if Gem::Version.new(MongoMapper::Version) <= Gem::Version.new("0.9.1")
              context = slug_options[:callback][1][:on]
              if context == :create
                condition = {:if => Proc.new { |record| record.new_record? }}
              elsif context == :update
                condition = {:if => Proc.new { |record| !record.new_record? }}
              end
            end
            self.send(slug_options[:callback][0], :set_slug, condition)
          else
            self.send(slug_options[:callback], :set_slug)
          end
        end

        def all_slug_fields
          # first determine whether only a single field is processed or multiple localized versions of a field, and prepare
          # the input
          slug_fields = []
          if slug_options[:locales].present?
            slug_options[:locales].each do |loc|
              options = slug_options.dup
              options[:key] = "#{options[:key]}_#{loc}".to_sym
              options[:to_slug] = "#{options[:to_slug]}_#{loc}".to_sym
              slug_fields.push(options)
            end
          else
            slug_fields.push(slug_options)
          end
          slug_fields
        end
      end

      module InstanceMethods
        def set_slug
          slug_fields = self.class.all_slug_fields

          slug_fields.each do |options|
            need_set_slug = self.send(options[:key]).blank? || (options[:force] && self.send(:"#{options[:to_slug]}_changed?"))
            next unless need_set_slug

            to_slug = self[options[:to_slug]]
            next if to_slug.blank?

            the_slug = raw_slug = to_slug.send(options[:method]).to_s[0...options[:max_length]]

            conds = {}
            conds[options[:key]]   = the_slug
            conds[options[:scope]] = self.send(options[:scope]) if options[:scope]

            # todo - remove the loop and use regex instead so we can do it in one query
            i = 0
            while self.class.first(conds)
              i += 1
              conds[options[:key]] = the_slug = "#{raw_slug}-#{i}"
            end

            self.send(:"#{options[:key]}=", the_slug)
          end
        end

        def to_param(suffix=I18n.locale)
          options = self.class.all_slug_fields
          options = options.length > 1 ? options.find {|field| field[:key].to_s.ends_with? suffix.to_s } : options.first
          ( self.send(options[:key]) || self.id ).to_s
        end
      end
    end
  end
end

