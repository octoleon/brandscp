# == Schema Information
#
# Table name: attached_assets
#
#  id                    :integer          not null, primary key
#  file_file_name        :string(255)
#  file_content_type     :string(255)
#  file_file_size        :integer
#  file_updated_at       :datetime
#  asset_type            :string(255)
#  attachable_id         :integer
#  attachable_type       :string(255)
#  created_by_id         :integer
#  updated_by_id         :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  active                :boolean          default("true")
#  direct_upload_url     :string(255)
#  rating                :integer          default("0")
#  folder_id             :integer
#  status                :integer          default("0")
#  processing_percentage :integer          default("0")
#

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :attached_asset do
    file_file_name 'filetest.jpg'
    file_file_size 12_345
    file_content_type 'image/jpg'
    file_updated_at Time.now
    attachable nil
    created_by_id 1
    updated_by_id 1
    status 2
    active true

    factory :document do
      asset_type 'document'
    end

    factory :photo do
      asset_type 'photo'
    end

    factory :video do
      asset_type 'photo'
      file_file_name 'filetest.flv'
      file_content_type 'video/x-flv'
    end
  end
end
