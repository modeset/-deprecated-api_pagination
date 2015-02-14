module Api
  module Pagination
    module Simple

      PER_PAGE_DEFAULT = 25
      PER_PAGE_MAX = 100

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def page(num_or_params = 1)
          scope = limit(PER_PAGE_DEFAULT)
          scope = scope.extending { include ScopeMethods }

          if num_or_params.is_a?(Hash)
            scope = scope.offset(PER_PAGE_DEFAULT * ([num_or_params[:page].to_i, 1].max - 1))
            scope = scope.per(num_or_params[:per_page])
          else
            scope = scope.offset(PER_PAGE_DEFAULT * ([num_or_params.to_i, 1].max - 1))
          end

          scope
        end
      end

      module ScopeMethods
        include Api::Pagination::CommonInterface

        # additional scopes
        def per(num)
          return self if (num = num.to_i) <= 0
          num = [PER_PAGE_MAX, num].min
          limit(num).offset(offset_value / limit_value * num)
        end

        # counts
        def total_count
          @total_count ||= begin
            scope = except(:offset, :limit, :order)
            scope = scope.except(:includes) unless references_eager_loaded_tables?
            scope.count(:all)
          end
        end

        def total_pages
          (total_count.to_f / limit_value).ceil
        end

        def total_pages_remaining
          total_pages - current_page
        end

        # determiners
        def first_page?
          current_page == 1
        end

        def last_page?
          current_page >= total_pages
        end

        # param values
        def first_page_value
          1
        end

        def last_page_value
          total_pages
        end

        def prev_page_value
          current_page - 1 unless first_page?
        end

        def next_page_value
          current_page + 1 unless last_page?
        end

        # param helper
        def page_param(params, page, _)
          params[:page] = page
          params
        end

        private

        def current_page
          (offset_value / limit_value) + 1
        end

      end
    end
  end
end
