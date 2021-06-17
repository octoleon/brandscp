# == Schema Information
#
# Table name: invites
#
#  id            :integer          not null, primary key
#  event_id      :integer
#  venue_id      :integer
#  market        :string(255)
#  invitees      :integer          default("0")
#  rsvps_count   :integer          default("0")
#  attendees     :integer          default("0")
#  final_date    :date
#  created_at    :datetime
#  updated_at    :datetime
#  active        :boolean          default("true")
#  created_by_id :integer
#  updated_by_id :integer
#

class Invite < ActiveRecord::Base
  track_who_does_it

  belongs_to :event
  belongs_to :venue
  has_one :place, through: :venue
  has_many :individuals, class_name: 'InviteIndividual',
                         inverse_of: :invite, dependent: :destroy

  delegate :name_with_location, :id, :name, to: :place, prefix: true, allow_nil: true
  delegate :jameson_locals?, :top_venue?, to: :venue, allow_nil: true
  delegate :campaign_name, :campaign_id, to: :event, prefix: false, allow_nil: true

  validates :event, presence: true
  validates :venue, presence: true
  validates :invitees, presence: true, numericality: true

  scope :active, -> { where active: true }

  def self.find_by_remote_id(remote_id)
    joins(:individuals).find_by(invite_individuals: { remote_id: remote_id })
  end

  def place_reference=(value)
    @place_reference = value
    return unless value && value.present?
    place = find_place_by_reference(value)
    return unless place.present?
    if place.persisted?
      self.venue = Venue.find_or_initialize_by(place_id: place.id, company_id: Company.current.id)
    else
      self.venue = Venue.new(place: place.id, company: Company.current)
    end
  end

  def place_reference
    if place_id.present?
      place_id
    else
      "#{place.reference}||#{place.place_id}" if place.present?
    end
  end

  def find_place_by_reference(value)
    place =
      if value.to_s =~ /^[0-9]+$/
        Place.find(value)
      else
        reference, place_id = value.split('||')
        Place.load_by_place_id(place_id, reference)
      end
    place.save unless place.persisted?
    place
  end

  def activate!
    update_attribute :active, true
  end

  def deactivate!
    update_attribute :active, false
  end
end
