collection @photos

node do |photo|
  if photo.is_a?(AttachedAsset)
    node(:type) { :app }
    partial "api/v1/photos/photo", :object => photo
  else
    node(:type) { :google }
    partial "api/v1/photos/google", :object => photo
  end
end