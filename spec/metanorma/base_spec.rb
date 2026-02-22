require "spec_helper"

RSpec.describe Metanorma::Lawgr::Converter do
  it "processes a minimal lawgr document" do
    input = <<~INPUT
      #{ASCIIDOC_BLANK_HDR}

      [heading=article]
      == Σκοπός

      Σκοπός του παρόντος είναι...
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    expect(output).to include("<lawgr-standard")
    expect(output).to include('type="article"')
  end

  it "processes document header metadata" do
    input = <<~INPUT
      = ΝΟΜΟΣ ΥΠ' ΑΡΙΘ. 4330
      :docnumber: 4330
      :doctype: act
      :copyright-year: 2015
      :published-date: 2015-06-16
      :language: el
      :script: Grek
      :fek-number: 59
      :fek-series: Α'
      :fek-year: 2015
      :publisher: ΕΘΝΙΚΟ ΤΥΠΟΓΡΑΦΕΙΟ
      :mn-document-class: lawgr
      :nodoc:
      :novalid:
      :no-isobib:

      [heading=article]
      == Σκοπός

      Test.
    INPUT
    output = Asciidoctor.convert(input, *OPTIONS)
    expect(output).to include("<docidentifier")
    expect(output).to include("4330")
    expect(output).to include("<doctype>act</doctype>")
    expect(output).to include("<fek>")
    expect(output).to include("<number>59</number>")
    expect(output).to include("<series>Α'</series>")
    expect(output).to include("<year>2015</year>")
  end

  it "rejects invalid document types" do
    input = <<~INPUT
      = Test
      :doctype: invalid-type
      :nodoc:
      :novalid:
      :no-isobib:
      :docnumber: 1

      Text.
    INPUT
    expect { Asciidoctor.convert(input, *OPTIONS) }.not_to raise_error
  end
end
