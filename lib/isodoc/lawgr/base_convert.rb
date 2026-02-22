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

      # Add CSS classes to all <ol> elements for reliable styling.
      # Lowergreek gets its native type removed (inline labels handle it).
      # Other types keep their HTML type but also get a class for CSS
      # counter targeting (avoids browser case-sensitivity quirks with
      # attribute selectors on type="i" vs type="I").
      OL_CLASS = {
        "arabic" => "ol-arabic",
        "alphabet" => "ol-alphabet",
        "alphabet_upper" => "ol-alphabet-upper",
        "roman" => "ol-roman",
        "roman_upper" => "ol-roman-upper",
      }.freeze

      def ol_attrs(node)
        attrs = super
        xml_type = node["type"]
        if xml_type == "lowergreek"
          attrs.delete(:type)
          attrs[:class] = "lowergreek"
        elsif OL_CLASS[xml_type]
          attrs[:class] = OL_CLASS[xml_type]
        end
        attrs
      end

      # Render fmt-name content as inline <span class="ol-label"> for
      # ALL ordered-list items.  The base converter skips fmt-name
      # because standard flavours use native browser numbering via
      # <ol type>.  We render labels inline so they are selectable,
      # consistently styled, and support hanging-indent via CSS.
      def li_parse(node, out)
        out.li **attr_code(id: node["id"]) do |li|
          li << li_checkbox(node)
          if node.parent.name == "ol"
            fmt = node.at(ns("./fmt-name"))
            if fmt
              li.span class: "ol-label" do |span|
                fmt.children.each { |n| parse(n, span) }
              end
            end
          end
          node.children.each do |n|
            n.name == "fmt-name" and next
            parse(n, li)
          end
        end
      end

      def convert_i18n_init1(docxml)
        super
        @lang = "el" if docxml.xpath(ns("//bibdata/language")).empty?
      end
    end
  end
end
