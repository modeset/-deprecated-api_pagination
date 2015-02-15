module Api
  module Pagination
    module Timestamp

      PER_PAGE_DEFAULT = 25
      PER_PAGE_MAX = 100
      TIMESTAMP_FORMAT = '%Y-%m-%dT%H:%M:%S.%N%z'

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def page_by(params = {})
          options = page_options_from_params(params)

          scope = limit(PER_PAGE_DEFAULT)
          scope = scope.extending { include ScopeMethods }
          scope = scope.set_pagination_options(options.merge(scope: scope)).per(options[:per_page])
          add_timestamp_page_scope(scope, options)
        end

        def add_timestamp_page_scope(scope, options)
          time = parse_time(options[:before] || options[:after])
          scope = scope.where(where_for_timestamp_page(options, time)) if time
          sql = options[:query_column].send(options[:order]).to_sql.gsub('"', '')
          scope.order(sql)
        end

        private

        def where_for_timestamp_page(options, time)
          if options[:before].present?
            options[:query_column].lt(time)
          else
            options[:query_column].gt(time)
          end
        end

        def page_options_from_params(params = {})
          options = params.dup || {}
          options[:column] ||= :created_at
          options[:order] = options[:after].present? ? :asc : :desc
          options[:query_column] = sanitized_column(options[:column])
          options
        end

        def sanitized_column(column)
          table_name, column_name = column.to_s.gsub(/[\s";\(\)]+/, '').split('.')
          if table_name && column_name
            Arel::Table.new(table_name, arel_engine)[column_name]
          else
            arel_table[column]
          end
        end

        def parse_time(value)
          Time.zone.parse(value.to_s)
        rescue
          raise InvalidTimestampError, value
        end
      end

      module ScopeMethods
        include Api::Pagination::CommonInterface

        # additional scopes
        def per(num)
          return self if (num = num.to_i) <= 0
          num = [PER_PAGE_MAX, num].min
          except(:limit).limit(num)
        end

        # counts
        def total_count(column_name = :all)
          @total_count ||= begin
            scope = @values[:_pagination_options][:scope]
            scope = scope.except(:includes) unless references_eager_loaded_tables?
            scope.count(column_name)
          end
        end

        def total_pages
          (total_count.to_f / limit_value).ceil
        end

        def total_pages_remaining
          [(total_remaining.to_f / limit_value).ceil - 1, 0].max
        end

        # determiners
        def first_page?
          @is_first_page ||= total_remaining >= total_count
        end

        def last_page?
          @is_last_page ||= total_remaining <= limit_value
        end

        # param values
        def first_page_value
          true
        end

        def last_page_value
          true
        end

        def prev_page_value
          @prev_page ||= page_value_for(first)
        end

        def next_page_value
          @next_page ||= page_value_for(last)
        end

        # param helper
        def page_param(params, page, rel)
          ord = @values[:_pagination_options][:order]
          param, param_inverse = ord == :asc ? [:after, :before] : [:before, :after]

          params = params.except(param, param_inverse)
          rel == 'prev' || rel == 'last' ? params[param_inverse] = page : params[param] = page
          params
        end

        private

        def total_remaining
          @total_remaining ||= except(:limit, :select).count
        end

        def page_value_for(record)
          return nil unless record
          if (callback = @values[:_pagination_options][:page_value]).respond_to?(:call)
            value = callback.call(record)
            value = value.try(:strftime, TIMESTAMP_FORMAT) if value.respond_to?(:strftime)
            value
          else
            record.try(@values[:_pagination_options][:column]).try(:strftime, TIMESTAMP_FORMAT)
          end
        end

      end
    end
  end
end
