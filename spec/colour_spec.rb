require 'spec_helper'

describe RubyRTF::Colour do
  it 'returns the rgb when to_s is called' do
    c = RubyRTF::Colour.new(255, 200, 199)
    expect(c.to_s).to eq '[255, 200, 199]'
  end
end