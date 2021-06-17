class BasePresenter < SimpleDelegator
  STRFTIME_FORMAT = '%Y-%m-%d %H:%M:%S'.freeze
  EXPORT_FORMAT = '%F %R'.freeze

  attr_accessor :model, :view

  def initialize(model, view)
    @model, @view = model, view
    super(@model)
  end

  def model=(model)
    @model = model
    __setobj__ model
  end

  def h
    @view
  end

  def datetime(d)
    Timeliness.parse(d.strftime(STRFTIME_FORMAT), zone: 'UTC').strftime(EXPORT_FORMAT)
  end

  def can?(action)
    h.can?(action, @model)
  end

  def timeago_tag(date)
    h.content_tag(:abbr, '', title: date.iso8601, class: :timeago)
  end

  def format_date_with_time(date)
    if date.strftime('%Y') == Time.zone.now.year.to_s
      date.strftime('%^a <b>%b %e</b> at %l:%M %p').html_safe unless date.nil?
    else
      date.strftime('%^a <b>%b %e, %Y</b> at %l:%M %p').html_safe unless date.nil?
    end
  end

  def icon(name)
    h.content_tag(:i, '', class: "icon icon-#{name}")
  end

  def format_date(the_date, plain = false)
    unless the_date.nil?
      if plain
        if the_date.strftime('%Y') == Time.zone.now.year.to_s
          the_date.strftime('%^a %b %e')
        else
          the_date.strftime('%^a %b %e, %Y')
        end
      else
        if the_date.strftime('%Y') == Time.zone.now.year.to_s
          the_date.strftime('%^a <b>%b %e</b>').html_safe
        else
          the_date.strftime('%^a <b>%b %e, %Y</b>').html_safe
        end
      end
    end
  end
end
