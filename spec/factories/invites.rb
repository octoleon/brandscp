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

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :invite do
    association(:event)
    association(:venue)
    invitees 1
    rsvps_count 0
    attendees 1
    market nil
    final_date '2014-12-30'
    active true
  end
end
