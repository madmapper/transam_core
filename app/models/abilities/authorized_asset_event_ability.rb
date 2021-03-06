module Abilities
  class AuthorizedAssetEventAbility
    include CanCan::Ability

    def initialize(user, organization_ids=[])

      if organization_ids.empty?
        organization_ids = user.organization_ids
      end

      #-------------------------------------------------------------------------
      # Asset Events
      #-------------------------------------------------------------------------
      # Can manage asset events if the asset is owned by their organization
      can :manage, AssetEvent do |ae|
        ae.asset_event_type.try(:active) && organization_ids.include?(ae.send(Rails.application.config.asset_base_class_name.underscore).try(:organization_id))
      end

      cannot :create, DispositionUpdateEvent do |ae|
        !ae.send(Rails.application.config.asset_base_class_name.underscore).try(:disposable?,false)
      end


      cannot :create, EarlyDispositionRequestUpdateEvent do |ae|
        !ae.send(Rails.application.config.asset_base_class_name.underscore).try(:eligible_for_early_disposition_request?)
      end

      cannot [:approve, :reject, :approve_via_transfer], EarlyDispositionRequestUpdateEvent

      cannot [:update, :destroy], EarlyDispositionRequestUpdateEvent do |ae|
        ae.state != 'new'
      end

    end
  end
end