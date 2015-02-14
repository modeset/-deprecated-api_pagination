module Api
  module Pagination
    module CommonInterface

      def set_pagination_options(options = {})
        (@values ||= {})[:_pagination_options] = options
        self
      end

      # identifier
      def paginatable?
        true
      end

      # counts
      def total_count
        nil
      end

      def total_pages
        nil
      end

      def total_pages_remaining
        nil
      end

      # determiners
      def first_page?
        nil
      end

      def last_page?
        nil
      end

      # param values
      def first_page_value
        nil
      end

      def last_page_value
        nil
      end

      def prev_page_value
        nil
      end

      def next_page_value
        nil
      end

      # param helper
      def page_param(params, page_value, rel)
        nil
      end

    end
  end
end
