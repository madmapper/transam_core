require 'rails_helper'

RSpec.describe AssetSearcher, :type => :model do
  let(:asset) { create(:equipment_asset, :organization_id => 1) }
  let(:searcher) { AssetSearcher.new(:organization_id => asset.organization_id) }
  #------------------------------------------------------------------------------
  #
  # Simple Equality Searches
  #
  #------------------------------------------------------------------------------
  it 'should be able to search by manufacturer' do
    asset.update!(:manufacturer_id => 1)
    searcher.manufacturer_id = asset.manufacturer_id
    expect(searcher.respond_to?(:manufacturer_id)).to be true
    expect(searcher.data.count).to eq(Asset.where('manufacturer_id = ?', asset.manufacturer_id).count)
  end

  it 'should be able to search by asset type' do
    asset.update!(:asset_type_id => 1)
    searcher.asset_type_id = asset.asset_type_id
    expect(searcher.data.count).to eq(Asset.where('asset_type_id = ?', asset.asset_type_id).count)
  end

  it 'should be able to search by asset subtype' do
    asset.update!(:asset_subtype_id => 1)
    searcher.asset_subtype_id = asset.asset_subtype_id
    expect(searcher.respond_to?(:asset_subtype_id)).to be true
    expect(searcher.data.count).to eq(Asset.where('asset_subtype_id = ?', asset.asset_subtype_id).count)
  end

  it 'should be able to search by estimated condition type' do
    asset.update!(:estimated_condition_type_id => 1)
    searcher.estimated_condition_type_id = asset.estimated_condition_type_id
    expect(searcher.respond_to?(:estimated_condition_type_id)).to be true
    expect(searcher.data.count).to eq(Asset.where('estimated_condition_type_id = ?', asset.estimated_condition_type_id).count)
  end

  it 'should be able to search by reported condition type' do
    asset.update!(:reported_condition_type_id => 1)
    searcher.reported_condition_type_id = asset.reported_condition_type_id
    expect(searcher.respond_to?(:reported_condition_type_id)).to be true
    expect(searcher.data.count).to eq(Asset.where('reported_condition_type_id = ?', asset.reported_condition_type_id).count)
  end

  it 'should be able to search by service status' do
    asset.update!(:service_status_type_id => 1)
    searcher.service_status_type_id = asset.service_status_type_id
    expect(searcher.respond_to?(:service_status_type_id)).to be true
    expect(searcher.data.count).to eq(Asset.where('service_status_type_id = ?', asset.service_status_type_id).count)
  end
  # #------------------------------------------------------------------------------
  # #
  # # Comparator Searches
  # #
  # #------------------------------------------------------------------------------
  it 'should be able to search by purchase cost' do
    asset.update!(:purchase_cost => '10000')
    lesser = create(:equipment_asset, :purchase_cost => '2000', :organization_id => 1)

    searcher.purchase_cost = asset.purchase_cost
    searcher.purchase_cost_comparator = '0'
    expect(searcher.respond_to?(:purchase_cost)).to be true
    expect(searcher.data.count).to eq(Asset.where('purchase_cost = ?', asset.purchase_cost).count)

    searcher = AssetSearcher.new(:purchase_cost => asset.purchase_cost, :purchase_cost_comparator => '-1', :organization_id => asset.organization_id )
    expect(searcher.data.count).to eq(Asset.where('purchase_cost < ? AND assets.organization_id IN (?)', asset.purchase_cost, asset.organization_id).count)

    searcher = AssetSearcher.new(:purchase_cost => asset.purchase_cost, :purchase_cost_comparator => '1', :organization_id => asset.organization_id )
    expect(searcher.data.count).to eq(Asset.where('purchase_cost > ?', asset.purchase_cost).count)
  end

  it 'should be able to search by scheduled replacement year' do
    asset.update!(:scheduled_replacement_year => 2020)
    lesser = create(:equipment_asset, :scheduled_replacement_year => 2010, :organization_id => 1)

    searcher.scheduled_replacement_year = asset.scheduled_replacement_year
    searcher.scheduled_replacement_year_comparator ='0'

    expect(searcher.respond_to?(:scheduled_replacement_year)).to be true
    expect(searcher.data.count).to eq(Asset.where('scheduled_replacement_year = ?', asset.scheduled_replacement_year).count)

    searcher.scheduled_replacement_year_comparator = '-1'
    expect(searcher.data.count).to eq(Asset.where('scheduled_replacement_year < ?', asset.scheduled_replacement_year).count)

    searcher = AssetSearcher.new(:scheduled_replacement_year => asset.scheduled_replacement_year, :scheduled_replacement_year_comparator => '1', :organization_id => asset.organization_id )
    expect(searcher.data.count).to eq(Asset.where('scheduled_replacement_year > ?', asset.scheduled_replacement_year).count)
  end

  it 'should be able to search by policy replacement year' do
    asset.update!(:policy_replacement_year => 2020)
    lesser = create(:equipment_asset, :policy_replacement_year => 2010, :organization_id => 1)

    searcher = AssetSearcher.new(:policy_replacement_year => asset.policy_replacement_year, :policy_replacement_year_comparator => '0', :organization_id => asset.organization_id )
    expect(searcher.respond_to?(:policy_replacement_year)).to be true
    expect(searcher.data).to eq(Asset.where('policy_replacement_year = ?', asset.policy_replacement_year).to_a)

    searcher = AssetSearcher.new(:policy_replacement_year => asset.policy_replacement_year, :policy_replacement_year_comparator => '-1', :organization_id => asset.organization_id )
    expect(searcher.data.count).to eq(Asset.where('policy_replacement_year < ?', asset.policy_replacement_year).count)

    searcher = AssetSearcher.new(:policy_replacement_year => asset.policy_replacement_year, :policy_replacement_year_comparator => '1', :organization_id => asset.organization_id )
    expect(searcher.data).to eq(Asset.where('policy_replacement_year > ?', asset.policy_replacement_year).to_a)
  end

  it 'should be able to search by purchase date' do
    asset = create(:equipment_asset, :purchase_date => Date.today, :organization_id => 1)
    lesser = create(:equipment_asset, :purchase_date => Date.new(2000,1,1), :organization_id => 1)

    searcher = AssetSearcher.new(:purchase_date => asset.purchase_date, :purchase_date_comparator => '0', :organization_id => asset.organization_id )
    expect(searcher.respond_to?(:purchase_date)).to be true
    expect(searcher.data.count).to eq(Asset.where('purchase_date = ? AND assets.organization_id IN (?)', asset.purchase_date, asset.organization_id).count)

    searcher = AssetSearcher.new(:purchase_date => asset.purchase_date, :purchase_date_comparator => '-1', :organization_id => asset.organization_id )
    expect(searcher.data.count).to eq(Asset.where('purchase_date < ? AND assets.organization_id IN (?)', asset.purchase_date, asset.organization_id).count)

    searcher = AssetSearcher.new(:purchase_date => asset.purchase_date, :purchase_date_comparator => '1', :organization_id => asset.organization_id )
    expect(searcher.data.count).to eq(Asset.where('purchase_date > ? AND assets.organization_id IN (?)', asset.purchase_date, asset.organization_id).count)
  end

  it 'should be able to search by manufacture year' do
    asset = create(:equipment_asset, :manufacture_year => 2010, :organization_id => 1)
    lesser = create(:equipment_asset, :manufacture_year => 2000, :organization_id => 1)

    searcher = AssetSearcher.new(:manufacture_year => asset.manufacture_year, :manufacture_year_comparator => '0', :organization_id => asset.organization_id )
    expect(searcher.respond_to?(:manufacture_year)).to be true
    expect(searcher.data.count).to eq(Asset.where('manufacture_year = ? AND assets.organization_id IN (?)', asset.manufacture_year, asset.organization_id).count)

    searcher = AssetSearcher.new(:manufacture_year => asset.manufacture_year, :manufacture_year_comparator => '-1', :organization_id => asset.organization_id )
    expect(searcher.data.count).to eq(Asset.where('manufacture_year < ? AND assets.organization_id IN (?)', asset.manufacture_year, asset.organization_id).count)

    searcher = AssetSearcher.new(:manufacture_year => asset.manufacture_year, :manufacture_year_comparator => '1', :organization_id => asset.organization_id )
    expect(searcher.data.count).to eq(Asset.where('manufacture_year > ? AND assets.organization_id IN (?)', asset.manufacture_year, asset.organization_id).count)
  end

  it 'should be able to search by in service date' do
    asset = create(:equipment_asset, :in_service_date => Date.today, :organization_id => 1)
    lesser = create(:equipment_asset, :in_service_date => Date.new(2000,1,1), :organization_id => 1)

    searcher = AssetSearcher.new(:in_service_date => asset.in_service_date, :in_service_date_comparator => '0', :organization_id => asset.organization_id )
    expect(searcher.respond_to?(:in_service_date)).to be true
    expect(searcher.data.count).to eq(Asset.where('in_service_date = ? AND assets.organization_id IN (?)', asset.in_service_date, asset.organization_id).count)

    searcher = AssetSearcher.new(:in_service_date => asset.in_service_date, :in_service_date_comparator => '-1', :organization_id => asset.organization_id )
    expect(searcher.data.count).to eq(Asset.where('in_service_date < ? AND assets.organization_id IN (?)', asset.in_service_date, asset.organization_id).count)

    searcher = AssetSearcher.new(:in_service_date => asset.in_service_date, :in_service_date_comparator => '1', :organization_id => asset.organization_id )
    expect(searcher.data.count).to eq(Asset.where('in_service_date > ? AND assets.organization_id IN (?)', asset.in_service_date, asset.organization_id).count)
  end

  # #------------------------------------------------------------------------------
  # #
  # # Checkbox Searches
  # #
  # #------------------------------------------------------------------------------

  it 'should be able to search by in backlog status' do
    asset = create(:equipment_asset, :in_backlog => true, :organization_id => 1)

    searcher = AssetSearcher.new(:in_backlog => "1", :organization_id => asset.organization_id )
    expect(searcher.respond_to?(:in_backlog)).to be true

    expect(searcher.data.count).to eq(Asset.where(in_backlog: true).count)
  end

  it 'should be able to search by in purchased new' do
    asset = create(:equipment_asset, :purchased_new => true, :organization_id => 1)

    searcher = AssetSearcher.new(:purchased_new => '1', :organization_id => asset.organization_id )
    expect(searcher.respond_to?(:purchased_new)).to be true

    expect(searcher.data.count).to eq(Asset.where('purchased_new = ? AND assets.organization_id IN (?)', asset.purchased_new, asset.organization_id).count)
  end

  # #------------------------------------------------------------------------------
  # #
  # # Non-Standard Searches
  # #
  # #------------------------------------------------------------------------------
  it 'should be able to search by manufacturer model' do
    asset = create(:equipment_asset, :manufacturer_model => 'test', :organization_id => 1)

    searcher = AssetSearcher.new(:manufacturer_model => asset.manufacturer_model, :organization_id => asset.organization_id )
    expect(searcher.respond_to?(:manufacturer_model)).to be true

    wildcard_search = "%#{asset.manufacturer_model}%"
    expect(searcher.data.count).to eq(Asset.where("manufacturer_model LIKE ?", wildcard_search).count)
  end

end
