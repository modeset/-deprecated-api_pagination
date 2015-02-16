module Api
  module Pagination
    module TimestampFilterable

      PER_PAGE_DEFAULT = 25
      PER_PAGE_MAX = 100
      PESSIMISTIC_MULTIPLIER = 2
      TIMESTAMP_FORMAT = '%Y-%m-%dT%H:%M:%S.%N%z'

      def filtered?
        raise MissingFilterMethodError, self.class.name
      end

      def self.included(base)
        base.extend(Timestamp::ClassMethods)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def filtered_page_by(params = {}, &block)
          options = page_options_from_params(params)
          options[:per_page] = options[:per_page].to_i
          options[:per_page] = PER_PAGE_DEFAULT if options[:per_page] <= 0
          options[:per_page] = [PER_PAGE_MAX, options[:per_page].to_i].min

          scope = self
          scope = block.call(self) if block_given?
          scope = scope.limit(options[:per_page] * PESSIMISTIC_MULTIPLIER)
          scope = scope.extending { include Timestamp::ScopeMethods }
          scope = scope.set_pagination_options(options)

          FilteredPage.new(self, scope, options)
        end
      end

      class FilteredPage
        include Enumerable
        extend Forwardable
        include Api::Pagination::CommonInterface

        delegate [:to_ary, :each, :size, :length, :first, :last] => :results
        delegate [:limit_value] => :@scope

        def initialize(ar_scope, scope, options)
          @ar_scope = ar_scope
          @scope = scope
          @options = options

          @results = [] # simulated enumerator
          @sql = to_sql
          load_page(@scope, @options) unless @options[:lazy]
        end

        # additional scopes
        def to_sql
          @ar_scope.add_timestamp_page_scope(@scope, @options).to_sql
        end

        def results
          load_page(@scope, @options) unless @loaded
          @results
        end

        # counts
        # fall back to the interface / nil since it can't be calculated

        # determiners
        def first_page?
          @is_first_page ||= if @options[:order] == :desc
            @options[:before].to_s == 'true'
          else
            @options[:after].to_s == 'true'
          end
        end

        def last_page?
          @is_last_page ||= @options[:after].to_s == 'true'
        end

        # param values
        def first_page_value
          true
        end

        def last_page_value
          true
        end

        def prev_page_value
          @prev_page ||= page_value_for(@results.first)
          return true if !@prev_page && (@options[:before].present? || @options[:after].present?)
          @prev_page
        end

        def next_page_value
          @next_page ||= page_value_for(@results.last)
        end

        # param helper
        def page_param(params, page, rel)
          ord = @options[:order]
          param, param_inverse = ord == :asc ? [:after, :before] : [:before, :after]

          params = params.except(param, param_inverse)
          rel == 'prev' ? params[param_inverse] = page : params[param] = page
          params
        end

        private

        def load_page(scope, options, recursion = false)
          @loaded = true
          local_scope = @ar_scope.add_timestamp_page_scope(scope, options)
          return if recursion && local_scope.to_sql == @sql
          return if (records = local_scope.to_a).empty?

          filter_results(records)
          load_page(scope, updated_options(options, records.last), true) unless done?
        end

        def filter_results(records)
          records.each do |record|
            next if record_filtered?(record)
            @results << record
            break if done?
          end
        end

        def record_filtered?(record)
          return @options[:filter].call(record) if @custom_filterer ||= @options[:filter].respond_to?(:call)
          record.send(:filtered?)
        end

        def updated_options(options, last)
          if options[:order] == :desc
            options[:before] = last.try(@options[:column])
          else
            options[:after] = last.try(@options[:column])
          end
          options
        end

        def done?
          @results.length >= @scope.limit_value / PESSIMISTIC_MULTIPLIER
        end

        def page_value_for(record)
          if (callback = @options[:page_value]).respond_to?(:call)
            value = callback.call(record)
            value = value.try(:strftime, TIMESTAMP_FORMAT) if value.respond_to?(:strftime)
            value
          else
            record.try(@options[:column]).try(:strftime, TIMESTAMP_FORMAT)
          end
        end

      end
    end
  end
end
