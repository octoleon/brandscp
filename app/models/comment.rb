# == Schema Information
#
# Table name: comments
#
#  id               :integer          not null, primary key
#  commentable_id   :integer
#  commentable_type :string(255)
#  content          :text
#  created_by_id    :integer
#  updated_by_id    :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class Comment < ActiveRecord::Base
  track_who_does_it

  acts_as_readable on: :created_at

  belongs_to :commentable, polymorphic: true
  belongs_to :user, foreign_key: 'created_by_id'
  belongs_to :created_by, class_name: 'User'
  belongs_to :updated_by, class_name: 'User'

  delegate :full_name, to: :user, prefix: true, allow_nil: true

  delegate :company_id, :campaign_id, to: :commentable

  validates :content, presence: true
  validates :commentable_id, presence: true, numericality: true
  validates :commentable_type, presence: true

  validate :max_event_comments, on: :create, if: proc { |c| c.commentable.is_a?(Event) }

  scope :for_places, ->(places, company) { joins('INNER JOIN events e ON e.id = commentable_id and commentable_type=\'Event\'').where(['e.place_id in (?) and e.company_id in (?)', places, company]) }

  scope :for_tasks_assigned_to, ->(users) { joins('INNER JOIN tasks t ON t.id = commentable_id and commentable_type=\'Task\'').where(['t.company_user_id in (?)', users]) }

  scope :for_tasks_where_user_in_team, ->(users) { joins('INNER JOIN tasks t ON t.id = commentable_id and commentable_type=\'Task\'').where("t.event_id in (#{Event.select('events.id').with_user_in_team(users).to_sql})") }

  scope :not_from, ->(user) { where(['comments.created_by_id<>?', user]) }

  scope :for_user_accessible_events, ->(company_user) { joins('INNER JOIN events ec ON ec.id = commentable_id and commentable_type=\'Event\' and ec.id in (' + Event.select('events.id').where(company_id: company_user.company_id).accessible_by_user(company_user).to_sql + ')') }

  scope :for_trends, -> { joins('INNER JOIN events e ON e.id = commentable_id and commentable_type=\'Event\'').where('e.active=?', true) }

  after_create :reindex_event
  after_commit :reindex_trending

  after_save :send_notifications

  def for_task?
    commentable.is_a?(Task)
  end

  private

  def reindex_event
    Sunspot.index commentable if commentable.is_a?(Event)
  end

  def send_notifications
    return unless commentable_type == 'Task'

    # Case when Task has an assigned user
    if commentable.company_user.present?
      if commentable.company_user.allow_notification?('new_comment_sms')
        sms_message = I18n.translate('notifications_sms.new_comment',
                                     url: Rails.application.routes.url_helpers.mine_tasks_url(task: [commentable_id],
                                                                                              anchor: "comments-#{commentable_id}"))
        SendSmsWorker.perform_async(commentable.company_user.phone_number, sms_message)
      end
      if commentable.company_user.allow_notification?('new_comment_email')
        email_message = I18n.translate('notifications_email.new_comment',
                                       url: Rails.application.routes.url_helpers.mine_tasks_url(task: [commentable_id],
                                                                                                anchor: "comments-#{commentable_id}"))
        UserMailer.delay.notification(commentable.company_user.id, I18n.translate('notification_types.new_comment'), email_message)
      end
    elsif commentable.event.present? # Case when Task has not an assigned user, send messages to all event's team
      sms_message = I18n.translate('notifications_sms.new_team_comment',
                                   url: Rails.application.routes.url_helpers.mine_tasks_url(task: [commentable_id],
                                                                                            anchor: "comments-#{commentable_id}"))
      commentable.event.all_users.each do |user|
        if user.allow_notification?('new_team_comment_sms')
          SendSmsWorker.perform_async(user.phone_number, sms_message)
        end
        if user.allow_notification?('new_team_comment_email')
          email_message = I18n.translate('notifications_email.new_team_comment',
                                         url: Rails.application.routes.url_helpers.mine_tasks_url(task: [commentable_id],
                                                                                                  anchor: "comments-#{commentable_id}"))
          UserMailer.delay.notification(user.id, I18n.translate('notification_types.new_team_comment'), email_message)
        end
      end
    end
  end

  def reindex_trending
    return unless commentable.is_a?(Event)
    Sunspot.index TrendObject.new(self)
  end

  def max_event_comments
    return true unless commentable.campaign.range_module_settings?('comments')
    max = commentable.campaign.module_setting('comments', 'range_max')
    return true if max.blank? || commentable.comments.count < max.to_i
    errors.add(:base, I18n.translate('instructive_messages.execute.comment.add_exceeded', count: max.to_i))
  end
end
