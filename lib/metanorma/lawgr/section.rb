module Metanorma
  module Lawgr
    module Section
      HEADING_TYPES = %w[book part section tmima chapter article
                         subarticle paragraph custom].freeze

      SEMANTIC_TYPES = %w[general-provisions substantive-provisions
                          organisational-provisions sanctions
                          delegating-provisions transitional-provisions
                          repealed-provisions entry-into-force].freeze

      # Greek law does not use standard StanDoc preface/main clause names.
      # Suppress automatic recognition of "foreword", "scope", etc.
      PREFACE_CLAUSE_NAMES = %w[donotrecognise-foreword
                                acknowledgements].freeze

      def sectiontype_streamline(ret)
        case ret
        when "foreword", "introduction" then "donotrecognise-foreword"
        else
          super
        end
      end

      # Override section_attributes to map heading= to type=.
      # The base standoc reads type= directly, but Greek law adoc
      # uses heading= for structural hierarchy (article, paragraph, etc.).
      def section_attributes(node)
        attrs = super
        heading = node.attr("heading")
        if heading && HEADING_TYPES.include?(heading)
          if attrs[:type] && attrs[:type] != heading
            attrs[:"semantic-type"] = attrs[:type]
          end
          attrs[:type] = heading
        end
        attrs
      end

      def title_validate(_root)
        nil
      end

      # Default ordered-list type follows the Greek law three-level
      # scheme when the author has not set an explicit style:
      #   depth 1–2  →  lowergreek  (α, β… στ, ζ…)
      #   depth 3+   →  roman       (i, ii, iii…)
      # An explicit style (e.g. [arabic]) is left untouched.
      def ol_attrs(node)
        attrs = super
        unless node.attributes[1] # no author-specified style
          depth = ol_nesting_depth(node)
          attrs[:type] = depth <= 2 ? "lowergreek" : "roman"
          attrs.delete(:"explicit-type")
        end
        attrs
      end

      private

      def ol_nesting_depth(node)
        depth = 0
        cursor = node.parent
        while cursor
          if cursor.respond_to?(:context) &&
              %i[olist ulist].include?(cursor.context)
            depth += 1
          end
          cursor = cursor.respond_to?(:parent) ? cursor.parent : nil
        end
        depth + 1
      end
    end
  end
end
