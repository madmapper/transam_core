#-------------------------------------------------------------------------------
# Role
#-------------------------------------------------------------------------------
class Role < ActiveRecord::Base

  #-----------------------------------------------------------------------------
  # Behaviors
  #-----------------------------------------------------------------------------
  scopify

  #-----------------------------------------------------------------------------
  # Associations
  #-----------------------------------------------------------------------------
  has_many :users_roles
  has_many :users, :through => :users_roles

  belongs_to :resource, :polymorphic => true
  belongs_to :role_parent, :class_name => 'Role'

  #-----------------------------------------------------------------------------
  # Scopes
  #-----------------------------------------------------------------------------
  default_scope { order(:weight) }
  # True roles
  scope :roles, -> { where(privilege: false) }
  # Privilege roles
  scope :privileges, -> { where(privilege: true) }

  #-----------------------------------------------------------------------------
  # Class Methods
  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------
  # Instance Methods
  #-----------------------------------------------------------------------------

  def to_s
    name
  end

  def privilege?
    (privilege)
  end

end
