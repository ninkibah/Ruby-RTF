require 'spec_helper'

describe RubyRTF::Font do
  let(:font) { RubyRTF::Font.new }

  it 'has a name' do
    font.name = 'Arial'
    expect(font.name).to eq 'Arial'
  end

  it 'has a command' do
    font.family_command = :swiss
    expect(font.family_command).to eq :swiss
  end
end