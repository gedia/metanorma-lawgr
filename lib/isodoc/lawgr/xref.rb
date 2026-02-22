require "roman-numerals"
require "metanorma/lawgr/greek_numerals"

module IsoDoc
  module Lawgr
    class Xref < IsoDoc::Xref
      STRUCTURAL_TYPES = %w[book part tmima chapter article
                            subarticle paragraph].freeze

      def clause_order_main(_docxml)
        [{ path: "//sections/clause | //sections/terms | " \
                 "//sections/definitions",
           multi: true }]
      end
    end
  end
end
