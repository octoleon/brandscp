# == Schema Information
#
# Table name: areas_campaigns
#
#  id          :integer          not null, primary key
#  area_id     :integer
#  campaign_id :integer
#  exclusions  :integer          default("{}"), is an Array
#  inclusions  :integer          default("{}"), is an Array
#  events_ids  :integer          default("{}"), is an Array
#

class AreasCampaign < ActiveRecord::Base
  belongs_to :area
  belongs_to :campaign

  after_update do
    campaign.clear_locations_cache(area) if campaign.present?
    Rails.cache.delete(locations_cache_key)
  end

  attr_accessor :reference

  def self.find_by_area_id!(area_id)
    find_by!(area_id: area_id)
  end

  def self.update_areas_campaigns_events(area_id)
    AreasCampaign.where(area_id: area_id).each do |ac|
      events_ids = []
      Event.in_campaign_area(ac).where(company_id: ac.campaign.company_id).each do |event|
        events_ids << event.id if event.campaign_id == ac.campaign.id
      end if ac.campaign.present?
      ac.events_ids = events_ids
      ac.save
    end
  end

  # If place is in /North America/United States/California/Los Angeles and the area
  # includes Los Angeles or any parent (like California)
  def place_in_scope?(place)
    return false unless place.present?
    @place_ids ||= area.place_ids - exclusions + inclusions
    return true if place.persisted? && @place_ids.include?(place.id)
    political_location = Place.political_division(place).join('/').downcase
    locations.any? { |location| political_location.include?(location.path) }
  end

  def locations
    @locations ||= Rails.cache.fetch(locations_cache_key) do
      Location.joins('INNER JOIN places ON places.location_id=locations.id')
          .where(places: { id: area.place_ids + inclusions, is_location: true })
          .where.not(places: { id: exclusions + [0] })
          .group('locations.id')
    end
  end

  def locations_cache_key
    "area_campaign_locations_#{area_id}_#{campaign.id}"
  end

  def location_ids
    locations.map(&:id)
  end

  def places
    Place.connection.unprepared_statement do
      Place.find_by_sql("
        #{area.places.to_sql} UNION #{Place.where(id: inclusions).to_sql}
        ORDER BY name
      ")
    end
  end

  def place_reference(value)
    return unless value && value.present?
    if value =~ /^[0-9]+$/
      Place.find(value)
    else
      reference, place_id = value.split('||')
      Place.find_or_create_by(place_id: place_id) do |p|
        p.reference = reference
      end
    end
  end
end
