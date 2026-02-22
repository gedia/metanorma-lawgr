require "spec_helper"

RSpec.describe "Validation" do
  it "warns on invalid document type" do
    input = <<~INPUT
      = Test
      :doctype: badtype
      :nodoc:
      :novalid:
      :no-isobib:
      :docnumber: 1

      Text.
    INPUT
    expect { Asciidoctor.convert(input, *OPTIONS) }.not_to raise_error
  end
end
