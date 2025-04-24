class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :confirmable,
         :recoverable, :rememberable, :validatable

  # Statuses ordered by decreasing privileges
  enum :status, {
    admin: 4,       # admin level access
    active: 3,      # read-write user level access
    restricted: 2,  # read-only user level access
    locked: 1,      # disallowed to sign in due to failed logins; maintained by Devise :lockable
    disabled: 0,    # administratively disallowed to sign in
  }, default: :active

  has_many :readouts, dependent: :destroy
  accepts_nested_attributes_for :readouts
  has_many :quantities, dependent: :destroy
  has_many :units, dependent: :destroy

  validates :email, presence: true, uniqueness: true,
    length: {maximum: type_for_attribute(:email).limit}
  validates :unconfirmed_email, length: {maximum: type_for_attribute(:unconfirmed_email).limit}
  validates :status, presence: true, inclusion: { in: statuses.keys }

  def to_s
    email
  end

  def at_least(status)
    return false unless User.statuses.key?(status.to_s)
    User.statuses[self.status] >= User.statuses[status]
  end
end
