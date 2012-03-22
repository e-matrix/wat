# -*- encoding : utf-8 -*-

#
# =Class User
# 
# * The user.name is used as a key to due readable URLs like /users/andi-altendorfer
# * A user can embed many authentications (omni-* incl. omni-identity)
# * A user can embed many [Facilities]
# * Whenever the email is changed, the :email_confirmed_at invalidats until the user
#   confirms his new address (UserMailer::registration_confirmation)
#
# ==Facilities
#
# ...can be used like:
# 
#    user = User.first
#    user.facilities.create( name: 'Author', access: 'r--')
#
#    if user.can_read?('Author')
#      yes, User can read with Author-access
#    end
#
#    if user.can_write?('Author')
#      no we'll not reach this line for this example-user
#    end
#
class User
  include Mongoid::Document
  include Mongoid::Timestamps
  
  key                     :name
  validates_presence_of   :name
  validates_uniqueness_of :name

  field                   :email, :type => String 
  validates_format_of     :email, :with => /^[-a-z0-9_+\.]+\@([-a-z0-9]+\.)+[a-z0-9]{2,4}$/i, :allow_nil => true

  field                   :confirm_email_token
  field                   :email_confirmed_at, :type => DateTime

  embeds_many             :authentications
  embeds_many             :facilities
  
  # Accessible Attributes
  attr_accessible :name, :email

  # Destroy omni-identities when delete the user
  # There is no association between User and Identity. So, we have to do this
  # with this two filters.
  before_destroy :memorize_identity
  after_destroy  :clear_identity

  # Add an authentication to this user
  # @param [Hash] auth - as provided by omni-auth
  def add_omniauth(auth)
    self.authentications.find_or_create_by( 
      provider: auth['provider'],
      uid: auth['uid'].to_s
    )
  end

  # Create a new user using omniauth information
  # @param [Hash] auth The hash returned by omniauth-provider
  # @return User or nil if it can't be found nor created.
  def self.create_with_omniauth(auth,current_user)
    
    _name = auth['info']['name']
    _uid  = auth['info']['uid'].to_s
    _provider=auth['info']['provider']

    # e.g. Foursquare doesn't fill 'info[:name]'
    # in this case join first_name and last_name
    unless _name
      _name = [auth['info']['first_name']||'', auth['info']['last_name']||''].join(" ")
    end
    
    # Find a user with this authentication
    _user = User.where( 
      :authentications.matches => {
         :provider => _provider, :uid => _uid
      }
    ).first
    
    # Use current_user or create a new user
    unless _user
      _user = current_user || create(name: _name) do |user|
        user.email ||= auth['info']['email'] if auth['info']['email'].present?
        user.authentications.create(
          provider: auth['provider'],
          uid: auth['uid'].to_s
        )
      end
      _user.save
    end

    _user
  end

  # Find a User by a given authentication
  # @param [String] provider like 'twitter', 'facebook', ...
  # @param [String] uid of this user at this provider
  # @return [User] or nil if not found by authentication
  def self.find_with_authentication(provider, uid)
    User.where(:authentications.matches => { provider: provider, uid: uid.to_s}).first
  end

  # Adds an authentication to this user
  # @param [Authentication]
  def add_authentication(authentication)
    authentications << authentication
  end

  # @param [String] what - A facility-name
  # @return [Boolean] true if User.facilities.where(name: what, access: /r../)
  def can_read?(what)
    facility = self.facilities.where(name: what).first
    facility && facility.can_read? && self.email_confirmed?
  end

  # @param [String] what - A facility-name
  # @return [Boolean] true if User.facilities.where(name: what, access: /.w./)
  def can_write?(what)
    facility = self.facilities.where(name: what).first
    facility && facility.can_write? && self.email_confirmed?
  end

  # @param [String] what - A facility-name
  # @return [Boolean] true if User.facilities.where(name: what, access: /..x/)
  def can_execute?(what)
    facility = self.facilities.where(name: what).first
    facility && facility.can_execute? && self.email_confirmed?
  end

  # Join all facility-names with access modes. "Admin (rwx), Author (rw-), ..."
  # yield a given block with this string or return the string otherwise.
  # @return [String] - if no block given
  def facilities_string(&block)
    if self.facilities.any?
      _string = I18n.translate(:facilities, list: self.facilities.map{|f| "#{f.name} (#{f.access})"}.join(", "))
      if block_given?
        yield _string
      else
        _string
      end
    else
      unless block_given?
        ""
      end
    end
  end

  # Generate a new random token and set email_confirmed_at to nil
  # UsersControler will set email_confirmed_at when the user confirms the new address
  def generate_confirm_email_token!
    self.confirm_email_token = SecureRandom.hex(10)
    self.email_confirmed_at = nil
    self.save!
  end

  # @return [Boolean] true if email_confirmed_at has a value
  def email_confirmed?
    self.email_confirmed_at != nil
  end


private
  # Save Identities to remove after destroy. Called by before_filter
  # @return [Identity] or nil if no Identity exists
  def memorize_identity
    @identity_to_remove = Identity.where(name: self.name).first
  end

  # Model Identity is handeled by omniauth-identity which is not
  # connected in any way to our user-model. To clean up unused
  # Identities we have to delete through this user's authentications
  # Called by after_filter  
  def clear_identity
    @identity_to_remove.delete if @identity_to_remove
  end
end

