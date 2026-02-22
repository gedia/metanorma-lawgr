require "asciidoctor"
require "metanorma/standoc/converter"
require_relative "base"
require_relative "front"
require_relative "section"
require_relative "cleanup"
require_relative "validate"

module Metanorma
  module Lawgr
    class Converter < Standoc::Converter
      XML_ROOT_TAG = "lawgr-standard".freeze
      XML_NAMESPACE = "https://www.metanorma.org/ns/lawgr".freeze

      register_for "lawgr"

      include Base
      include Front
      include Section
      include Cleanup
      include Validate
    end
  end
end
