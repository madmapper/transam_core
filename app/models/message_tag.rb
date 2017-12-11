#-------------------------------------------------------------------------------
#
# Message Tag
#
# Map relation that maps a message to a user as part of a tag.
#
#-------------------------------------------------------------------------------
class MessageTag < ActiveRecord::Base
  #-----------------------------------------------------------------------------
  # Callbacks
  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------
  # Associations
  #-----------------------------------------------------------------------------
  # Every message_tag belongs to a message
  belongs_to  :message

  # Every message_tag belongs to a user
  belongs_to  :user

  #-----------------------------------------------------------------------------
  # Scopes
  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------
  # Validations
  #-----------------------------------------------------------------------------
  validates     :message,       :presence => true
  validates     :user,          :presence => true

  #-----------------------------------------------------------------------------
  # Constants
  #-----------------------------------------------------------------------------

  # List of allowable form param hash keys
  FORM_PARAMS = [
  ]

  #-----------------------------------------------------------------------------
  #
  # Class Methods
  #
  #-----------------------------------------------------------------------------

  def self.allowable_params
    FORM_PARAMS
  end

  #-----------------------------------------------------------------------------
  #
  # Instance Methods
  #
  #-----------------------------------------------------------------------------

  #-----------------------------------------------------------------------------
  #
  # Protected Methods
  #
  #-----------------------------------------------------------------------------
  protected

end
