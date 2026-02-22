require "fileutils"

module IsoDoc
  module Lawgr
    module BaseConvert
      LAWGR_TYPES = %w[book part tmima chapter article subarticle
                       paragraph custom].freeze

      # Scan all paragraph and subarticle labels in the presentation XML
      # and compute the maximum label width (in ch units) for each
      # numbering depth.  This must be called before clause_attrs so
      # that every div can receive the correct CSS custom properties.
      def precompute_paragraph_widths(docxml)
        @paragraph_indent_by_segments = {}
        @subarticle_max_num_width = 0
        @custom_max_num_width = 0
        docxml.xpath("//*[@type='paragraph' or @type='subarticle' or @type='custom']").each do |node|
          fmt_t = node.at(".//*[local-name()='fmt-title']") or next
          lbl_el = fmt_t.at(".//*[@class='fmt-caption-label']") or next
          lbl = lbl_el.text.strip
          lbl.empty? and next
          # +1 char for trailing period, +0.6 for gap
          len = lbl.length + 1.6
          case node["type"]
          when "subarticle"
            @subarticle_max_num_width = [@subarticle_max_num_width, len].max
          when "custom"
            @custom_max_num_width = [@custom_max_num_width, len].max
          else
            segments = lbl.count(".") + 1
            cur = @paragraph_indent_by_segments[segments] || 0
            @paragraph_indent_by_segments[segments] = [cur, len].max
          end
        end
      end

      def clause_attrs(node)
        attrs = super
        ctype = node["type"]
        if ctype && LAWGR_TYPES.include?(ctype)
          attrs[:class] = [attrs[:class], "lawgr-#{ctype}"]
                            .compact.join(" ")
          if ctype == "subarticle" && @subarticle_max_num_width &&
              @subarticle_max_num_width > 0
            attrs[:style] = "--lawgr-sub-num-width: " \
                            "#{@subarticle_max_num_width}ch"
          elsif ctype == "custom" && @custom_max_num_width &&
              @custom_max_num_width > 0
            attrs[:style] = "--lawgr-custom-num-width: " \
                            "#{@custom_max_num_width}ch"
          elsif ctype == "paragraph" && @paragraph_indent_by_segments
            lbl = paragraph_label_text(node)
            if lbl && !lbl.empty?
              segments = lbl.count(".") + 1
              width = @paragraph_indent_by_segments[segments]
              attrs[:style] = "--lawgr-num-width: #{width}ch" if width
            end
          end
        end
        attrs
      end

      def paragraph_label_text(node)
        fmt_t = node.at(".//*[local-name()='fmt-title']") or return nil
        lbl_el = fmt_t.at(".//*[@class='fmt-caption-label']") or return nil
        lbl_el.text.strip
      end

      def middle_clause(_docxml)
        "//clause[parent::sections]"
      end

      def norm_ref_xpath
        "//null"
      end

      def bibliography_xpath
        "//bibliography/clause[.//references] | " \
          "//bibliography/references"
      end

      def convert_i18n_init1(docxml)
        super
        @lang = "el" if docxml.xpath(ns("//bibdata/language")).empty?
      end
    end
  end
end
