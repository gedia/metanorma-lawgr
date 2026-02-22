require_relative "base_convert"
require_relative "init"
require "isodoc"

module IsoDoc
  module Lawgr
    class PdfConvert < IsoDoc::PdfConvert
      def initialize(options)
        @libdir = File.dirname(__FILE__)
        super
      end

      include BaseConvert
      include Init
    end
  end
end
