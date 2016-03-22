#-------------------------------------------------------------------------------
#
# Asset
#
# Base class for all assets. This class represents a generic asset, subclasses represent concrete
# asset types.
#
#-------------------------------------------------------------------------------
class Asset < ActiveRecord::Base

  OBJECT_CACHE_EXPIRE_SECONDS = Rails.application.config.object_cache_expire_seconds
  # The policy analyzer to use comes from the Rails config
  POLICY_ANALYZER = Rails.application.config.policy_analyzer

  #-----------------------------------------------------------------------------
  # Behaviors
  #-----------------------------------------------------------------------------
  include TransamObjectKey
  include TransamNumericSanitizers
  include FiscalYear

  #-----------------------------------------------------------------------------
  # Callbacks
  #-----------------------------------------------------------------------------
  after_initialize  :set_defaults

  # Clean up any HABTM associations before the asset is destroyed
  before_destroy { asset_groups.clear }

  # Before the asset is updated we may need to update things like estimated
  # replacement cost if they updated other things
  before_update   :before_update_callback, :except => :create

  before_update :clear_cache

  #-----------------------------------------------------------------------------
  # Associations common to all asset types
  #-----------------------------------------------------------------------------

  # each asset belongs to a single organization
  belongs_to  :organization

  # each asset has a single asset type
  belongs_to  :asset_type

  # each asset has a single asset subtype
  belongs_to  :asset_subtype

  # each asset has a single maintenance provider type
  belongs_to  :maintenance_provider_type

  # each asset has a reason why it is being replaced
  belongs_to  :replacement_reason_type

  # each was puchased from a vendor
  belongs_to  :vendor

  # each belongs to a single manufacturer
  belongs_to  :manufacturer

  # each can belong to a parent
  belongs_to  :parent, :class_name => "Asset",  :foreign_key => :parent_id

  # Each asset has zero or more asset events. These are all events regardless of
  # event type. Events are deleted when the asset is deleted
  has_many   :asset_events, :dependent => :destroy

  # each asset has zero or more condition updates
  has_many   :condition_updates, -> {where :asset_event_type_id => ConditionUpdateEvent.asset_event_type.id }, :class_name => "ConditionUpdateEvent"

  # each asset has zero or more scheduled replacement updates
  has_many   :schedule_replacement_updates, -> {where :asset_event_type_id => ScheduleReplacementUpdateEvent.asset_event_type.id }, :class_name => "ScheduleReplacementUpdateEvent"

  # each asset has zero or more scheduled rehabilitation updates
  has_many   :schedule_rehabilitation_updates, -> {where :asset_event_type_id => ScheduleRehabilitationUpdateEvent.asset_event_type.id }, :class_name => "ScheduleRehabilitationUpdateEvent"

  # each asset has zero or more recorded rehabilitation events
  has_many   :rehabilitation_updates, -> {where :asset_event_type_id => RehabilitationUpdateEvent.asset_event_type.id}, :class_name => "RehabilitationUpdateEvent"

  # each asset has zero or more scheduled disposition updates
  has_many   :schedule_disposition_updates, -> {where :asset_event_type_id => ScheduleDispositionUpdateEvent.asset_event_type.id }, :class_name => "ScheduleDispositionUpdateEvent"

  # each asset has zero or more service status updates
  has_many   :service_status_updates, -> {where :asset_event_type_id => ServiceStatusUpdateEvent.asset_event_type.id }, :class_name => "ServiceStatusUpdateEvent"

  # each asset has zero or more disposition updates
  has_many   :disposition_updates, -> {where :asset_event_type_id => DispositionUpdateEvent.asset_event_type.id }, :class_name => "DispositionUpdateEvent"

  # each asset has zero or more location updates.
  has_many   :location_updates, -> {where :asset_event_type_id => LocationUpdateEvent.asset_event_type.id }, :class_name => "LocationUpdateEvent"

  # Each asset has zero or more images. Images are deleted when the asset is deleted
  has_many    :images,      :as => :imagable,       :dependent => :destroy

  # Each asset has zero or more documents. Documents are deleted when the asset is deleted
  has_many    :documents,   :as => :documentable, :dependent => :destroy

  # Each asset has zero or more comments. Documents are deleted when the asset is deleted
  has_many    :comments,    :as => :commentable,  :dependent => :destroy

  # Each asset has zero or more tasks. Tasks are deleted when the asset is deleted
  has_many    :tasks,       :as => :taskable,     :dependent => :destroy

  # Each asset can have 0 or more dependents
  has_many    :dependents,  :class_name => 'Asset', :foreign_key => :parent_id, :dependent => :nullify

  # Each asset can be associated with 0 or more asset groups
  has_and_belongs_to_many :asset_groups

  # Each asset was created and updated by a user
  belongs_to :creator, :class_name => "User", :foreign_key => :created_by_id
  belongs_to :updator, :class_name => "User", :foreign_key => :updated_by_id

  # Has been tagged by the user
  has_many    :asset_tags
  has_many    :users, :through => :asset_tags

  # Validations on associations
  validates     :organization_id,     :presence => true
  validates     :asset_type_id,       :presence => true
  validates     :asset_subtype_id,    :presence => true
  validates     :created_by_id,       :presence => true
  validates     :manufacture_year,    :presence => true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 1900}
  validates     :expected_useful_life, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}, :presence => true
  validates_inclusion_of :purchased_new, :in => [true, false]
  validates     :purchase_cost,       :presence => :true, :numericality => {:only_integer => :true, :greater_than_or_equal_to => 0}
  validates     :purchase_date,       :presence => :true
  validates     :serial_number,       uniqueness: {scope: :organization, message: "must be unique within an organization"}, allow_nil: true, allow_blank: true

  #validates     :in_service_date,     :presence => :true

  #-----------------------------------------------------------------------------
  # Attributes common to all asset types
  #-----------------------------------------------------------------------------

  # Validations on core attributes
  validates       :asset_tag,         :presence => true, :length => { :maximum => 12 }
  # Asset tags must be unique within an organization
  validates_uniqueness_of :asset_tag, :scope => :organization

  #-----------------------------------------------------------------------------
  # Attributes that are used to cache asset condition information.
  # This set of attributes are updated when the asset condirtion or disposition is
  # updated. Used for reporting only.
  #-----------------------------------------------------------------------------

  # The last reported condition type for the asset
  belongs_to      :reported_condition_type,   :class_name => "ConditionType",   :foreign_key => :reported_condition_type_id

  # The last estimated condition type for the asset
  belongs_to      :estimated_condition_type,  :class_name => "ConditionType",   :foreign_key => :estimated_condition_type_id

  # The disposition type for the asset. Null if the asset is still operational
  belongs_to      :disposition_type

  # The last reported disposition type for the asset
  belongs_to      :service_status_type

  #-----------------------------------------------------------------------------
  # Transient Attributes
  #-----------------------------------------------------------------------------
  attr_reader :vendor_name

  #-----------------------------------------------------------------------------
  # Scopes
  #-----------------------------------------------------------------------------
  # Returns a list of assets that have been disposed
  scope :disposed,    -> { where('assets.disposition_date IS NOT NULL') }
  # Returns a list of assets that are still operational
  scope :operational, -> { where('assets.disposition_date IS NULL') }
  # Returns a list of asset that operational and are marked as being in service
  scope :in_service,  -> { where('assets.disposition_date IS NULL AND assets.service_status_type_id = 1')}
  #-----------------------------------------------------------------------------
  # Lists. These lists are used by derived classes to make up lists of attributes
  # that can be used for operations like full text search etc. Each derived class
  # can add their own fields to the list
  #-----------------------------------------------------------------------------

  # List of fields which can be searched using a simple text-based search
  SEARCHABLE_FIELDS = [
    :object_key,
    :asset_tag,
    :external_id,
    :description,
    :manufacturer_model
  ]

  # List of fields that should be nilled when a copy is made
  CLEANSABLE_FIELDS = [
    'object_key',
    'asset_tag',
    'external_id',
    'policy_replacement_year',
    'estimated_replacement_year',
    'estimated_replacement_cost',
    'scheduled_replacement_year',
    'scheduled_rehabilitation_year',
    'scheduled_disposition_year',
    'replacement_reason_type_id',
    'in_backlog',
    'reported_condition_type_id',
    'reported_condition_rating',
    'reported_condition_date',
    'reported_mileage',
    'estimated_condition_type_id',
    'estimated_condition_rating',
    'service_status_type_id',
    'disposition_type_id',
    'disposition_date'
 ]

  UPDATE_METHODS = [
    :update_sogr,
    :update_service_status,
    :update_condition,
    :update_scheduled_replacement,
    :update_scheduled_rehabilitation,
    :update_scheduled_disposition,
    :update_estimated_replacement_cost,
    :update_location
  ]

  # List of hash parameters allowed by the controller
  FORM_PARAMS = [
    :organization_id,
    :asset_type_id,
    :asset_subtype_id,
    :asset_tag,
    :external_id,
    :manufacture_year,
    :vendor_id,
    :vendor_name,
    :manufacturer_id,
    :manufacturer_model,
    :purchase_cost,
    :purchase_date,
    :purchased_new,
    :warranty_date,
    :in_service_date,
    :policy_replacement_year,
    :expected_useful_life,
    :estimated_replacement_year,
    :estimated_replacement_cost,
    :scheduled_replacement_year,
    :scheduled_rehabilitation_year,
    :scheduled_disposition_year,
    :replacement_reason_type_id,
    :in_backlog,
    :reported_condition_type_id,
    :reported_condition_rating,
    :reported_condition_date,
    :estimated_condition_type_id,
    :estimated_condition_rating,
    :service_status_type_id,
    :service_status_date,
    :disposition_date,
    :disposition_type_id,
    :parent_id,
    :superseded_by_id,
    :created_by_id,
    :updated_by_id
  ]

  #-----------------------------------------------------------------------------
  #
  # Class Methods
  #
  #-----------------------------------------------------------------------------

  # Returns an array of classes which are descendents of Asset, this includes classes
  # that are both direct and in-direct assendents.
  #
  # Example
  #
  #  class Truck < Asset
  #  end
  #
  #  class PickupTruck < Truck
  #  end
  #
  # Asset.descendents returns [Truck, PickupTruck]
  #
  def self.descendents
    ObjectSpace.each_object(Class).select { |klass| klass < self }
  end

  # Returns the list or allowable form parameters for this class
  def self.allowable_params
    FORM_PARAMS
  end

  # Factory method to return a strongly typed subclass of a new asset
  # based on the asset subtype
  def self.new_asset(asset_subtype)

    asset_class_name = asset_subtype.asset_type.class_name
    asset = asset_class_name.constantize.new({:asset_subtype_id => asset_subtype.id, :asset_type_id => asset_subtype.asset_type.id})
    return asset

  end

  # Returns a typed version of an asset. Every asset has a type and this will
  # return a specific asset type based on the AssetType attribute
  def self.get_typed_asset(asset)
    if asset
      class_name = asset.asset_type.class_name
      klass = Object.const_get class_name
      o = klass.find(asset.id)
      return o
    end
  end

  # Returns an array of asset event classes that this asset can process
  def self.event_classes
    a = []
    # Use reflection to return the list of has many associatiopns and filter those which are
    # events
    self.reflect_on_all_associations(:has_many).each do |assoc|
      a << assoc.klass if assoc.class_name.end_with? 'UpdateEvent'
    end
    a
  end

  #-----------------------------------------------------------------------------
  #
  # Instance Methods
  #
  #-----------------------------------------------------------------------------

  # Returns true if the user has tagged this asset
  def tagged? user
    users.include? user
  end

  # Tags this asset for the user
  def tag user
    unless tagged? user
      users << user
    end
  end

  # Returns true if the asset has been superseded
  def superseded?
    (self.superseded_by_id.present?)
  end

  # Returns the asset that replaced this asset if it has been replaced
  def superseded_by
    if self.superseded_by_id.present?
      Asset.get_typed_asset(Asset.find(self.superseded_by_id))
    else
      nil
    end
  end

  # Returns the asset that this asset replaced this asset if it has been replaced
  def supersedes
    asset = Asset.find_by(:superseded_by_id => self.id)
    if asset.present?
      Asset.get_typed_asset(asset)
    else
      nil
    end
  end

  # Render the asset as a JSON object -- overrides the default json encoding
  def as_json(options={})
    json = {
      :id => self.id,
      :object_key => self.object_key,
      :asset_tag => self.asset_tag,
      :external_id => self.external_id,

      :organization_id => self.organization.to_s,
      :asset_type_id=> self.asset_type.to_s,
      :asset_subtype_id => self.asset_subtype.to_s,

      :parent_id => self.parent.to_s,
      :name => self.name,
      :description => self.description,

      :service_status_type_id => self.service_status_type.present? ? self.service_status_type.code : nil,
      :age => self.age,
      :reported_condition_rating => self.reported_condition_rating,

      :scheduled_rehabilitation_year => self.scheduled_rehabilitation_year.present? ? fiscal_year(self.scheduled_rehabilitation_year) : nil,
      :scheduled_replacement_year => self.scheduled_replacement_year.present? ? fiscal_year(self.scheduled_replacement_year) : nil,

      :manufacturer_id => self.manufacturer.present? ? self.manufacturer.to_s : nil,
      :manufacture_year => self.manufacture_year,

      :purchase_cost => self.purchase_cost,
      :purchase_date => self.purchase_date,
      :purchased_new => self.purchased_new,
      :warranty_date => self.warranty_date,
      :in_service_date => self.in_service_date,
      :vendor_id => self.vendor.present? ? self.vendor.to_s : nil,

      :created_at => self.created_at,
      :updated_at => self.updated_at,

      :tasks => self.tasks.active.count,
      :comments => self.comments.count,
      :documents => self.documents.count,
      :photos => self.images.count,

      :tagged => self.tagged?(options[:user]) ? 1 : 0
    }
    if self.respond_to? :book_value
      a = Asset.get_typed_asset self
      json.merge! a.depreciable_as_json
    end
    json
  end

  # Override to_s to return a reasonable default
  def to_s
    "#{asset_subtype.name}: #{asset_tag}"
  end

  # Override the getter for vendor name
  def vendor_name
    vendor.name unless vendor.nil?
  end

  # Returns true if the asset has one or more tasks that are open
  def needs_attention?
    (tasks.where('state IN (?)', Task.active_states).count > 0)
  end

  # Returns true if the asset is in service based on the last reported status update
  def in_service?
    service_status_type_id == ServiceStatusType.find_by(:code => 'I')
  end

  # Instantiate an asset event of the appropriate type.
  def build_typed_event(asset_event_type_class)
    # Could also add:  raise ArgumentError 'Asset Must be strongly typed' unless is_typed?

    # DO NOT cast to concrete type.  Want to enforce that client has a concrete asset
    unless self.class.event_classes.include? asset_event_type_class
      raise ArgumentError, 'Invalid Asset Event Type'
    end
    asset_event_type_class.new(:asset => self)
  end

  # Returns true if an asset has been disposed. This is the canonical method for checking
  # if an asset has been disposed. Always use this method rather than checking the
  # attributes as the data model might change
  def disposed?
    disposition_date.present?
  end

  # Returns true if the asset exists, i.e. has an in_service_date. If using this
  # method, make sure the context is well defined, for example, a building could
  # be under construction but is not yet in service, similary, a bus could have
  # been purchased but has not been placed into service.
  def exists?
    (in_service_date.present? and disposed? == false)
  end

  # Returns true if the asset can be disposed in the next planning cycle,
  # false otherwise
  def disposable?
    return false if disposed?
    # otherwise check the policy year and see if it is less than or equal to
    # the current planning year
    return false if policy_replacement_year.blank?

    (policy_replacement_year <= current_planning_year_year)
  end

  # Returns true if an asset is scheduled for disposition
  def scheduled_for_disposition?
    (scheduled_disposition_year.present? and disposed? == false)
  end

  # Returns true if an asset is scheduled for rehabilitation
  def scheduled_for_rehabilitation?
    (scheduled_rehabilitation_year.present? and disposed? == false)
  end

  # Returns true if the asset is of the specified class or has the specified class as
  # and ancestor (superclass).
  #
  # usage: a.type_of? type
  # where type can be one of:
  #    a symbol e.g :vehicle
  #    a class name eg Vehicle
  #    a string eg "vehicle"
  #
  def type_of?(type)
    begin
      self.class.ancestors.include?(type.to_s.classify.constantize)
    rescue
      false
    end
  end

  #-----------------------------------------------------------------------------
  # Override numeric setters to remove any extraneous formats from the number
  # strings eg $, etc.
  #-----------------------------------------------------------------------------
  def manufacture_year=(num)
    self[:manufacture_year] = sanitize_to_int(num)
  end

  def purchase_cost=(num)
    self[:purchase_cost] = sanitize_to_int(num)
  end

  def expected_useful_life=(num)
    self[:expected_useful_life] = sanitize_to_int(num)
  end
  #-----------------------------------------------------------------------------


  # Returns true if this asset participates in one or more events
  def has_events?
    event_classes.size > 0
  end

  # Returns an array of asset event classes that this asset can process
  def event_classes
    # get a typed version of the asset
    asset = is_typed? ? self : Asset.get_typed_asset(self)
    asset.class.event_classes
  end

  # Returns the initial cost of the asset. Derived classes should override this to
  # handle asset-class specific caluclations where needed
  def cost
    # get a typed version of the asset and return its value
    asset = is_typed? ? self : Asset.get_typed_asset(self)
    return asset.cost unless asset.nil?
  end

  # returns true if the asset instance is strongly typed, i.e., a concrete class
  # false otherwise.
  # true
  def is_typed?
    self.class.to_s == asset_type.class_name
  end

  # default name for an asset
  # sub classes should override this with a class-specific name
  def name
    return "#{asset_subtype.name} - #{asset_tag}"
  end

  # returns the number of months an asset has been in service
  def months_in_service(on_date=Date.today)
    if in_service_date.nil?
      0
    else
      (on_date.year * 12 + on_date.month) - (in_service_date.year * 12 + in_service_date.month)
    end
  end

  # returns the number of months since the asset was rehabilitated
  def months_since_rehabilitation(on_date=Date.today)
    if last_rehabilitation_date.nil?
      0
    else
      (on_date.year * 12 + on_date.month) - (last_rehabilitation_date.year * 12 + last_rehabilitation_date.month)
    end
  end

  # returns the number of years since the asset was placed in service.
  def age(on_date=Date.today)
    age_in_years = months_in_service(on_date)/12.0
    [(age_in_years).floor, 0].max
  end

  # returns the number of years since the asset was owned. It can't be less than 0
  # years_owned is currently calculated based off fiscal year
  def years_owned(on_date=Date.today)
    [fiscal_year_on_date(on_date) - fiscal_year_on_date(purchase_date), 0].max
  end

  # returns the number of years the asset is in service. It can't be less than 0
  # years_in_service is currently calculated based off fiscal year
  def years_in_service(on_date=Date.today)
    [fiscal_year_on_date(on_date,current_depreciation_date) - fiscal_year_on_date(in_service_date), 0].max
  end

  # Returns the fiscal year that the asset was placed in service
  def in_service_fiscal_year
    fiscal_year_on_date(in_service_date) unless in_service_date.nil?
  end

  # returns the list of events associated with this asset ordered by date, newest first
  def history
    AssetEvent.unscoped.where('asset_id = ?', id).order('event_date DESC')
  end

  def estimated_rehabilitation_cost(on_date = Date.today)
    calculate_estimated_rehabilitation_cost(on_date)
  end

  # Returns the total amount spent rehabilitating the asset
  def rehabilitation_cost
    if rehabilitation_updates.empty?
      0
    else
      rehabilitation_updates.map(&:cost)
    end
  end

  #-----------------------------------------------------------------------------
  # Return the policy analyzer for this asset. If a policy is not provided the
  # default policy for the asset is used
  #-----------------------------------------------------------------------------
  def policy_analyzer(policy_to_use=nil)
    if policy_to_use.blank?
      policy_to_use = policy
    end
    policy_analyzer = POLICY_ANALYZER.constantize.new(self, policy_to_use)
  end
  #-----------------------------------------------------------------------------
  # returns the the organizations's policy that governs the replacement of this
  # asset. This needs to upcast the organization type to a class that owns assets
  #-----------------------------------------------------------------------------
  def policy
    Organization.get_typed_organization(organization).get_policy
  end

  #-----------------------------------------------------------------------------
  # Record that the asset has been disposed. This updates the dispostion date
  # and the disposition_type attribute on the master record. It also sets the
  # ServiceStatusType to 'disposed'
  #
  # If the user removed the disposition event, the master record is reset by
  # removing the disposition type, disposition date and setting the service
  # status back to the last known status if on exists
  def record_disposition
    Rails.logger.info "Recording final disposition for asset = #{object_key}"

    # Make sure we are working with a concrete asset class
    asset = is_typed? ? self : Asset.get_typed_asset(self)

    unless asset.new_record?
      unless asset.disposition_updates.empty?
        event = asset.disposition_updates.last
        asset.disposition_date = event.event_date
        asset.disposition_type = event.disposition_type
        # Set the service status to disposed
        asset.service_status_type = ServiceStatusType.find_by(:code => 'D')
      else
        # The user is undo-ing the disposition update
        asset.disposition_type = nil
        asset.disposition_date = nil
        # Set the service status to the last known service status
        if asset.service_status_updates.empty?
          # Set to Uknown
          asset.service_status_type = ServiceStatusType.find_by(:code => 'U')
        else
          asset.service_status_type = asset.service_status_updates.last.service_status_type
        end
      end
      # save changes to this asset
      if asset.changed?
        asset.save(:validate => false)
      end
    end
  end

  # Forces an update of an assets location. This performs an update on the record.
  def update_location

    Rails.logger.debug "Updating the recorded location for asset = #{object_key}"

    unless new_record? or disposed?
      if location_updates.empty?
        self.parent_id = nil
        self.location_comments = nil
      else
        event = location_updates.last
        self.parent_id = event.parent_id
        self.location_comments = event.comments
      end
      # save changes to this asset
      if self.changed?
        save
      end
    end
  end

  def update_rehabilitation
    Rails.logger.debug "Updating the recorded rehabilitation for asset = #{object_key}"

    # Make sure we are working with a concrete asset class
    asset = is_typed? ? self : Asset.get_typed_asset(self)

    # can't do this if it is a new record as none of the IDs would be set
    unless asset.new_record? or disposed?
      if asset.rehabilitation_updates.empty?
        asset.last_rehabilitation_date = nil
      else
        asset.last_rehabilitation_date = asset.rehabilitation_updates.last.event_date
        asset.scheduled_rehabilitation_year = nil
      end
      # save changes to this asset
      if asset.changed?
        asset.save(:validate => false)
      end
    end
  end

  # Forces an update of an assets service status. This performs an update on the record
  def update_service_status
    Rails.logger.debug "Updating service status for asset = #{object_key}"

    # Make sure we are working with a concrete asset class
    asset = is_typed? ? self : Asset.get_typed_asset(self)

    # can't do this if it is a new record as none of the IDs would be set
    unless asset.new_record? or disposed?
      if asset.service_status_updates.empty?
        service_status_type = nil
        service_status_date = nil
      else
        event = asset.service_status_updates.last
        asset.service_status_date = event.event_date
        asset.service_status_type = event.service_status_type
      end
      # save changes to this asset
      if asset.changed?
        asset.save(:validate => false)
      end
    end
  end

  # Forces an update of an assets reported condition. This performs an update on the record.
  def update_condition

    Rails.logger.debug "Updating condition for asset = #{object_key}"

    # can't do this if it is a new record as none of the IDs would be set
    unless new_record? or disposed?
      if condition_updates.empty?
        self.reported_condition_date = nil
        self.reported_condition_rating = nil
        self.reported_condition_type = ConditionType.find_by(:name => "Unknown")
      else
        event = condition_updates.last
        self.reported_condition_date = event.event_date
        self.reported_condition_rating = event.assessed_rating
        self.reported_condition_type = ConditionType.from_rating(event.assessed_rating)
      end
      # save changes to this asset
      if self.changed?
        save(:validate => false)
      end
    end

  end

  # Forces an update of an assets scheduled replacement. This performs an update on the record.
  def update_scheduled_replacement

    Rails.logger.debug "Updating the scheduled replacement year for asset = #{object_key}"

    unless new_record? or disposed?
      if !schedule_replacement_updates.empty?
        event = schedule_replacement_updates.last
        self.scheduled_replacement_year = event.replacement_year unless event.replacement_year.nil?
        self.replacement_reason_type_id = event.replacement_reason_type_id unless event.replacement_reason_type_id.nil?
      end
      # save changes to this asset
      if self.changed?
        save(:validate => false)
      end
    end
  end

  # Forces an update of an assets scheduled replacement. This performs an update on the record.
  def update_scheduled_rehabilitation

    Rails.logger.debug "Updating the scheduled rehabilitation year for asset = #{object_key}"

    unless new_record? or disposed?
      if schedule_rehabilitation_updates.empty?
        self.scheduled_rehabilitation_year = nil
      else
        event = schedule_rehabilitation_updates.last
        self.scheduled_rehabilitation_year = event.rebuild_year
      end
      # save changes to this asset
      if self.changed?
        save(:validate => false)
      end
    end
  end

  # Forces an update of an assets scheduled disposition
  def update_scheduled_disposition

    Rails.logger.debug "Updating the scheduled disposition for asset = #{object_key}"

    unless new_record? or disposed?
      if schedule_disposition_updates.empty?
        self.scheduled_disposition_year = nil
      else
        event = schedule_disposition_updates.last
        self.scheduled_disposition_year = event.disposition_year
      end
      # save changes to this asset
      if self.changed?
        save(:validate => false)
      end
    end
  end


  def update_estimated_replacement_cost

    return if disposed?

    if self.policy_replacement_year < current_planning_year_year
      start_date = start_of_fiscal_year(scheduled_replacement_year)
    else
      start_date = start_of_fiscal_year(policy_replacement_year)
    end
    self.estimated_replacement_cost = calculate_estimated_replacement_cost(start_date)
    # save changes to this asset
    if self.changed?
      save(:validate => false)
    end

  end

  #-----------------------------------------------------------------------------
  # Calculates and stores the scheduled replacement for the asset based on the
  # scheduled replacement year
  #-----------------------------------------------------------------------------
  def update_scheduled_replacement_cost

    return if disposed?

    if self.scheduled_replacement_year.blank?
      start_date = start_of_fiscal_year(policy_replacement_year)
    else
      start_date = start_of_fiscal_year(scheduled_replacement_year)
    end
    self.scheduled_replacement_cost = calculate_estimated_replacement_cost(start_date)

    # save changes to this asset
    if self.changed?
      save(:validate => false)
    end

  end

  #-----------------------------------------------------------------------------
  # Calculates and returns the estimated replacement cost of this asset on the
  # current date or another date if given
  #-----------------------------------------------------------------------------
  def calculate_estimated_replacement_cost(on_date=nil)

    return if disposed?

    # Make sure we are working with a concrete asset class
    asset = is_typed? ? self : Asset.get_typed_asset(self)

    # Get the calculator class from the policy analyzer
    class_name = asset.policy_analyzer.get_replacement_cost_calculation_type.class_name
    # create an instance of this class and call the method
    calculator_instance = class_name.constantize.new
    calculator_instance.calculate_on_date(asset, on_date)

  end

  #-----------------------------------------------------------------------------
  # Calculates and returns the estimated rehabilitaiton cost of this asset on the
  # current date or another date if given
  #-----------------------------------------------------------------------------
  def calculate_estimated_rehabilitation_cost(on_date=nil)

    return if disposed?

    # Make sure we are working with a concrete asset class
    asset = is_typed? ? self : Asset.get_typed_asset(self)

    # Get the cost from the policy
    cost = asset.policy_analyzer.get_total_rehabilitation_cost
    # TODO - we should use the cost calculator to project this cost to the
    # on_date
    cost
  end

  # calculate the year that the asset will need replacing based on
  # a policy
  def calculate_replacement_year(policy = nil)

    return if disposed?

    # Make sure we are working with a concrete asset class
    asset = is_typed? ? self : Asset.get_typed_asset(self)
    # Get the calculator class from the policy analyzer
    class_name = asset.policy_analyzer.get_service_life_calculation_type.class_name
    # determine the last year that the vehicle is viable based on the policy
    last_year_for_service = calculate(asset, class_name)
    # the asset will need replacing the next year
    last_year_for_service + 1

  end

  # calculate the estimated year that the asset will need replacing based on
  # a policy
  def calculate_estimated_replacement_year(policy = nil)

    return if disposed?

    # Make sure we are working with a concrete asset class
    asset = is_typed? ? self : Asset.get_typed_asset(self)

    # Get the calculator class from the policy analyzer
    class_name = asset.policy_analyzer.get_condition_estimation_type.class_name
    # estimate the last year that the asset will be servicable
    last_year_for_service = calculate(asset, class_name, 'last_servicable_year')
    # the asset will need replacing the next year
    last_year_for_service + 1

  end

  # Creates a duplicate that has all asset-specific attributes nilled
  def copy(cleanse = true)
    a = dup
    a.cleanse if cleanse
    a
  end

  def searchable_fields
    SEARCHABLE_FIELDS
  end

  def update_methods
    a = []
    a << super rescue nil # Must call super in case an engine includes updates above Asset
    UPDATE_METHODS.each do |method|
      a << method
    end
    a.flatten
  end

  # nils out all fields identified to be cleansed
  def cleanse
    cleansable_fields.each do |field|
      send(:"#{field}=", nil) # Rather than set methods directly, delegate to setters.  This supports aliased attributes
    end
  end

  # Update the SOGR for an asset
  def update_sogr(policy = nil)
    unless disposed?
      update_asset_state(policy)
    end
  end
  # Update the replacement costs for an asset
  def update_sogr_costs
    unless disposed?
      update_asset_state(policy)
    end
  end

  # External method for managing an object's local cache
  def cache_clear(key)
    delete_cached_object(key)
  end
  def cache_clear_all
    clear_cache
  end

  #-----------------------------------------------------------------------------
  #
  # Protected Methods
  #
  #-----------------------------------------------------------------------------
  protected

  # Callback to update the asset when things change
  def before_update_callback

    Rails.logger.debug "In before_save_callback"
    # Get the policy analyzer

    this_policy_analyzer = self.policy_analyzer

    # If the policy replacement year changes we need to check to see if the asset
    # is in backlog and update the scheduled replacement year to the first planning
    # year
    if self.changes.include? "policy_replacement_year"
      Rails.logger.debug "New policy_replacement_year = #{self.policy_replacement_year}"

      if self.policy_replacement_year < current_planning_year_year
        self.scheduled_replacement_year = current_planning_year_year
        self.in_backlog = true
        start_date = start_of_fiscal_year(scheduled_replacement_year)
      else
        start_date = start_of_fiscal_year(policy_replacement_year)
      end
      # Update the estimated replacement costs
      Rails.logger.debug "Start Date = #{start_date}"
      class_name = this_policy_analyzer.get_replacement_cost_calculation_type.class_name
      calculator_instance = class_name.constantize.new
      self.estimated_replacement_cost = calculator_instance.calculate_on_date(self, start_date)
      Rails.logger.debug "estimated_replacement_cost = #{self.estimated_replacement_cost}"
    end
    if self.changes.include? "scheduled_replacement_year"
      Rails.logger.debug "New scheduled_replacement_year = #{self.scheduled_replacement_year}"
      # Get the calculator class from the policy analyzer
      class_name = this_policy_analyzer.get_replacement_cost_calculation_type.class_name
      calculator_instance = class_name.constantize.new
      start_date = start_of_fiscal_year(scheduled_replacement_year) unless scheduled_replacement_year.blank?
      Rails.logger.debug "Start Date = #{start_date}"
      self.scheduled_replacement_cost = calculator_instance.calculate_on_date(self, start_date)
    end
    true
  end

  # Return an object that has been cached against this asset
  def get_cached_object(key)
    Rails.cache.read(get_cache_key(key))
  end

  def delete_cached_object(key)
    Rails.cache.delete(get_cache_key(key))
  end

  # Cache an object against the asset
  def cache_object(key, obj, expires_in = OBJECT_CACHE_EXPIRE_SECONDS)
    Rails.cache.write(get_cache_key(key), obj, :expires_in => expires_in)
  end

  # Cache key for this asset
  def get_cache_key(key)
    "#{object_key}:#{key}"
  end

  # Cache key for this asset
  def clear_cache
    attributes.each { |attribute| delete_cached_object(attribute[0]) }
    # clear cache for other cached objects that are not attributes
    # hard-coded temporarily
    delete_cached_object('policy_rule')
  end

  # updates the calculated values of an asset
  def update_asset_state(policy = nil)
    Rails.logger.debug "Updating SOGR for asset = #{object_key}"

    if disposed?
      Rails.logger.debug "Asset #{object_key} is disposed"
    end

    # Make sure we are working with a concrete asset class
    asset = is_typed? ? self : Asset.get_typed_asset(self)

    # Get the policy analyzer
    policy_analyzer = asset.policy_analyzer

    # Use policy to update service life values
    update_service_life asset

    # returns the year in which the asset should be replaced based on the policy and asset
    # characteristics
    begin
      # see what metric we are using to determine the service life of the asset
      class_name = policy_analyzer.get_service_life_calculation_type.class_name
      asset.policy_replacement_year = calculate(asset, class_name)

      # If the asset is in backlog set the scheduled year to the current FY year
      if asset.policy_replacement_year < current_planning_year_year
        Rails.logger.debug "Asset is in backlog. Setting scheduled replacement year to #{current_planning_year_year}"
        asset.scheduled_replacement_year = current_planning_year_year
        asset.in_backlog = true
      else
        Rails.logger.debug "Setting scheduled replacement year to #{asset.policy_replacement_year}"
        asset.scheduled_replacement_year = asset.policy_replacement_year
        asset.in_backlog = false
      end
    rescue Exception => e
      Rails.logger.warn e.message
    end

    # Estimate the year that the asset will need replacing amd the estimated
    # condition of the asset
    begin
      class_name = policy_analyzer.get_condition_estimation_type.class_name
      asset.estimated_replacement_year = calculate(asset, class_name, 'last_servicable_year')

      asset.estimated_condition_rating = calculate(asset, class_name)
      asset.estimated_condition_type = ConditionType.from_rating(asset.estimated_condition_rating)
    rescue Exception => e
      Rails.logger.warn e.message
    end

    # Check for rehabilitation policy events
    begin
      # Use the calculator to calculate the policy rehabilitation fiscal year
      calculator = RehabilitationYearCalculator.new
      asset.policy_rehabilitation_year = calculator.calculate(asset)
    rescue Exception => e
      Rails.logger.warn e.message
    end

    # save changes to this asset
    if asset.changed?
      asset.save(:validate => false)
    end
  end

  def update_service_life typed_asset
    # Get the policy analyzer
    policy_analyzer = typed_asset.policy_analyzer

    typed_asset.expected_useful_life = policy_analyzer.get_min_service_life_months
  end


  def cleansable_fields
    CLEANSABLE_FIELDS
  end

  # Set reasonable defaults for a new asset
  def set_defaults
    self.purchase_date ||= Date.today
    self.in_service_date ||= self.purchase_date
    self.manufacture_year ||= Date.today.year
    self.purchased_new = self.purchased_new.nil? ? true : self.purchased_new
  end

  #-----------------------------------------------------------------------------
  #
  # Private Methods
  #
  #-----------------------------------------------------------------------------
  private

  # Calls a calculate method on a Calculator class to perform a condition or cost calculation
  # for the asset. The method name defaults to x.calculate(asset) but other methods
  # with the same signature can be passed in
  def calculate(asset, class_name, target_method = 'calculate')
    begin
      Rails.logger.debug "#{class_name}, #{target_method}"
      # create an instance of this class and call the method
      calculator_instance = class_name.constantize.new
      Rails.logger.debug "Instance created #{calculator_instance}"
      method_object = calculator_instance.method(target_method)
      Rails.logger.debug "Instance method created #{method_object}"
      method_object.call(asset)
    rescue Exception => e
      Rails.logger.error e.message
      raise RuntimeError.new "#{class_name} calculation failed for asset #{asset.object_key} and policy #{policy.name}"
    end
  end

end
