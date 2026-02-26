module Metanorma
  module Lawgr
    # Asciidoctor TreeProcessor that inserts invisible `eb:[]` inline
    # macros between source lines inside paragraph blocks and list-item
    # text.  Each `eb:[]` becomes an `<eb/>` element in the Standoc XML,
    # marking an εδάφιο (sentence-level) boundary.
    #
    # See DESIGN-ng-extra.adoc for the full specification.
    class EdafioTreeProcessor < Asciidoctor::Extensions::TreeProcessor
      def process(document)
        return document unless document.backend == "lawgr"

        ed_skip = collect_ed_block_children(document)

        document.find_by(context: :paragraph).each do |block|
          next if ed_skip.include?(block)
          next if has_explicit_ed?(block.lines)

          insert_eb_markers_block(block)
        end

        document.find_by(context: :list_item).each do |item|
          next if ed_skip.include?(item)
          raw_text = item.instance_variable_get(:@text)
          next unless raw_text
          next if has_explicit_ed_text?(raw_text)

          insert_eb_markers_list_item(item, raw_text)
        end

        document
      end

      private

      # Collect all paragraph blocks and list items that live inside
      # an `[.ed]` open block so auto-detection can skip them.
      def collect_ed_block_children(document)
        skip = Set.new
        document.find_by(context: :open).each do |block|
          next unless block.role == "ed"

          block.find_by(context: :paragraph).each { |p| skip << p }
          block.find_by(context: :list_item).each { |li| skip << li }
        end
        skip
      end

      def has_explicit_ed?(lines)
        lines.any? { |l| l.include?("[.ed]") }
      end

      def has_explicit_ed_text?(text)
        text.include?("[.ed]")
      end

      def insert_eb_markers_block(block)
        lines = block.lines
        new_lines = insert_markers(lines)
        block.lines.replace(new_lines) if new_lines != lines
      end

      def insert_eb_markers_list_item(item, raw_text)
        lines = raw_text.split("\n")
        return if lines.size <= 1

        new_lines = insert_markers(lines)
        if new_lines != lines
          item.instance_variable_set(:@text, new_lines.join("\n"))
        end
      end

      # Core marker insertion logic.
      # Between each pair of consecutive content lines, insert an eb:[]
      # marker.  Continuation-only lines (whitespace / bare `+`) are
      # skipped and do not count as εδάφιο boundaries.
      def insert_markers(lines)
        content_indices = []
        lines.each_with_index do |line, i|
          content_indices << i unless continuation_only?(line)
        end

        return lines if content_indices.size <= 1

        new_lines = lines.dup
        # Walk backwards so index offsets stay stable.
        (content_indices.size - 1).downto(1) do |ci|
          current_idx = content_indices[ci]
          prev_idx    = content_indices[ci - 1]

          if new_lines[prev_idx].rstrip.end_with?(" +")
            # Hard line break on previous line: prepend marker to current.
            new_lines[current_idx] = "eb:[] #{new_lines[current_idx]}"
          else
            # Normal line: append marker to previous line.
            new_lines[prev_idx] = "#{new_lines[prev_idx]} eb:[]"
          end
        end

        new_lines
      end

      # A line consisting only of whitespace and/or `+` is a formatting
      # artifact (list continuation), not a content line.
      def continuation_only?(line)
        stripped = line.strip
        stripped.empty? || stripped == "+"
      end
    end

    # Inline macro `eb:[]` → `<eb/>` in Standoc XML.
    class EbInlineMacro < Asciidoctor::Extensions::InlineMacroProcessor
      use_dsl
      named :eb
      using_format :short

      def process(_parent, _target, _attrs)
        "<eb/>"
      end
    end

    # Mixin for the Converter: intercept `[.ed]#text#` so it produces
    # `<span class="ed">text</span>` instead of the default highlight
    # markup.  All other inline_quoted types delegate to super.
    module EdafioInline
      def inline_quoted(node)
        if node.role == "ed" &&
            %i[unquoted mark].include?(node.type)
          noko do |xml|
            xml.span(class: "ed") { |s| s << node.text }
          end
        else
          super
        end
      end
    end
  end
end
