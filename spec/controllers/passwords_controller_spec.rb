require 'rails_helper'

RSpec.describe PasswordsController, :type => :controller do
  describe '.layout_by_resource' do
    it 'signed in' do
      sign_in create(:admin)
      expect(subject.layout_by_resource).to eq('application')
    end
    it 'not signed in' do
      expect(subject.layout_by_resource).to eq('password')
    end
  end
end
