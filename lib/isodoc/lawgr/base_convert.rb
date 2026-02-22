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

      # For lowergreek lists, suppress native <ol> numbering so we can
      # render the fmt-name labels inline instead.
      def ol_attrs(node)
        attrs = super
        if node["type"] == "lowergreek"
          attrs.delete(:type)
          existing = attrs[:style].to_s
          attrs[:style] = [existing, "list-style: none; padding-left: 0"]
                            .reject(&:empty?).join("; ")
        end
        attrs
      end

      # Render fmt-name content for lowergreek list items (the base
      # converter skips fmt-name because standard types use native
      # browser numbering).
      def li_parse(node, out)
        lowergreek = node.parent["type"] == "lowergreek"
        out.li **attr_code(id: node["id"]) do |li|
          li << li_checkbox(node)
          if lowergreek
            fmt = node.at(ns("./fmt-name"))
            if fmt
              li.span class: "ol-label" do |span|
                fmt.children.each { |n| parse(n, span) }
              end
              li << " "
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
