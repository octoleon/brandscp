class IncreaseAvgImpressionsHourField < ActiveRecord::Migration
  def up
    change_column :venues, :avg_impressions_hour, :decimal, precision: 10, scale: 2, default: 0
  end

  def down
    change_column :venues, :avg_impressions_hour, :decimal, precision: 6, scale: 2, default: 0
  end
end
