require "spec_helper"

RSpec.describe Metanorma::Lawgr::Processor do
  let(:processor) { described_class.new }

  it "registers against metanorma" do
    expect(Metanorma::Registry.instance.find_processor(:lawgr))
      .not_to be_nil
  end

  it "registers output formats against metanorma" do
    output = processor.output_formats
    expect(output[:html]).to eq "html"
    expect(output[:pdf]).to eq "pdf"
  end

  it "reports version" do
    expect(processor.version).to match(/Metanorma::Lawgr/)
  end
end
