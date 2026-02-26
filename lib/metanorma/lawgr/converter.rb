require "asciidoctor"
require "metanorma/standoc/converter"
require_relative "base"
require_relative "front"
require_relative "section"
require_relative "cleanup"
require_relative "validate"
require_relative "edafio_tree_processor"

module Metanorma
  module Lawgr
    class Converter < Standoc::Converter
      XML_ROOT_TAG = "lawgr-standard".freeze
      XML_NAMESPACE = "https://www.metanorma.org/ns/lawgr".freeze

      Asciidoctor::Extensions.register do
        tree_processor Metanorma::Lawgr::EdafioTreeProcessor
        inline_macro Metanorma::Lawgr::EbInlineMacro
      end

      register_for "lawgr"

      include Base
      include Front
      include Section
      include Cleanup
      include Validate
      include EdafioInline
    end
  end
end
