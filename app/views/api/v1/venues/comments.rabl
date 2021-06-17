collection @comments

node do |comment|
  if comment.is_a?(Comment)
    node(:type) { :app }
    partial "api/v1/comments/comment", :object => comment
  else
    node(:type) { :google }
    partial "api/v1/comments/google", :object => comment
  end
end