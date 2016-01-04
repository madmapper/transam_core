require 'rails_helper'

describe "assets/_comments.html.haml", :type => :view do
  it 'form' do
    assign(:asset, create(:buslike_asset))
    render

    expect(rendered).to have_content('There are no comments for this asset.')
    expect(rendered).to have_field('comment_comment')
  end
end
