class AddEventByQueryTool < ActiveRecord::DataMigration
  def up
    query_view_sql = <<-SQL
      CREATE OR REPLACE VIEW query_tool_most_recent_asset_events_for_type_view AS
      SELECT aet.id AS asset_event_type_id, aet.name AS asset_event_name, Max(ae.created_at) AS asset_event_created_time,
             ae.base_transam_asset_id, Max(ae.id) AS asset_event_id, CONCAT(u.first_name, " ", u.last_name) AS event_by
      FROM asset_events AS ae
      LEFT JOIN asset_event_types AS aet ON aet.id = ae.asset_event_type_id
      LEFT JOIN transam_assets AS ta  ON ta.id = ae.base_transam_asset_id
      LEFT JOIN users AS u ON u.id = ae.updated_by_id
      GROUP BY aet.id, ae.base_transam_asset_id;
    SQL
    ActiveRecord::Base.connection.execute query_view_sql

    qf = QueryField.find_or_create_by(
        name: 'event_by',
        label: 'Event By',
        query_category: QueryCategory.find_or_create_by(name: 'Life Cycle (History Log)'),
        filter_type: 'text'
    )
    qf.query_asset_classes = QueryAssetClass.where(table_name: 'most_recent_asset_events')
  end
end