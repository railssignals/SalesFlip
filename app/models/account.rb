class Account
  include Mongoid::Document
  include Mongoid::Timestamps
  include HasConstant
  include HasConstant::Orm::Mongoid
  include ParanoidDelete
  include Permission
  include Trackable
  include Activities
  include Sunspot::Mongoid

  field :name
  field :email
  field :access,            :type => Integer
  field :website
  field :phone
  field :fax
  field :billing_address
  field :shipping_address
  field :identifier,        :type => Integer
  field :account_type,      :type => Integer
  
  index :name

  has_constant :accesses, lambda { I18n.t('access_levels') }
  has_constant :account_types, lambda { I18n.t('account_types') }

  belongs_to_related :user, :index => true
  belongs_to_related :assignee, :class_name => 'User', :index => true
  belongs_to_related :parent, :class_name => 'Account', :index => true
  
  has_many_related   :contacts, :dependent => :nullify, :index => true
  has_many_related   :tasks, :as => :asset, :index => true
  has_many_related   :comments, :as => :commentable, :index => true
  has_many_related   :children, :class_name => 'Account', :foreign_key => 'parent_id', :index => true

  validates_presence_of :user, :name
  validates_uniqueness_of :email, :allow_blank => true

  before_create :set_identifier

  named_scope :for_company, lambda { |company| { :where => { :user_id.in => company.users.map(&:id) } } }
  named_scope :unassigned, :where => { :assignee_id => nil }
  named_scope :name_like, lambda { |name| { :where => { :name => /#{name}/i } } }

  searchable do
    text :name, :email, :phone, :website, :fax
  end

  def self.assigned_to( user_id )
    user_id = BSON::ObjectId.from_string(user_id) if user_id.is_a?(String)
    any_of({ :assignee_id => user_id }, { :user_id => user_id, :assignee_id => nil })
  end
  
  def self.similar_accounts( name )
    ids = Account.only(:id, :name).map do |account|
      [account.id, name.levenshtein_similar(account.name)]
    end.select { |similarity| similarity.last > 0.5 }.map(&:first)
    Account.where(:_id.in => ids)
  end

  def self.exportable_fields
    fields.map(&:first).sort.delete_if do |f|
      f.match(/access|permission|permitted_user_ids|tracker_ids/)
    end
  end

  def leads
    @leads ||= contacts.map(&:leads).flatten
  end

  alias :full_name :name

  def website=( website )
    website = "http://#{website}" if !website.nil? and !website.match(/^http:\/\//)
    write_attribute :website, website
  end

  def self.find_or_create_for( object, name_or_id, options = {} )
    account = Account.find(BSON::ObjectId.from_string(name_or_id.to_s))
  rescue BSON::InvalidObjectId => e
    account = Account.first(:conditions => { :name => name_or_id })
    account = create_for(object, name_or_id, options) unless account
    account
  end

  def self.create_for( object, name, options = {} )
    if options[:permission] == 'Object'
      permission = object.permission
      permitted = object.permitted_user_ids
    else
      permission = options[:permission] || 0
      permitted = options[:permitted_user_ids]
    end
    account = object.updater_or_user.accounts.create :permission => permission,
      :name => name, :permitted_user_ids => permitted, :account_type => 'Prospect'
  end

  def deliminated( deliminator, fields )
    fields.map { |field| self.send(field) }.join(deliminator)
  end

protected
  def set_identifier
    self.identifier = Identifier.next_account
  end
end
