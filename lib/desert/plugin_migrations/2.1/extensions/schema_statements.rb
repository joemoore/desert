ActiveRecord::ConnectionAdapters::SchemaStatements.module_eval do
  def initialize_schema_migrations_table_with_plugins
    initialize_schema_migrations_table_without_plugins

    begin
      execute "CREATE TABLE IF NOT EXISTS #{Desert::PluginMigrations::Migrator.schema_migrations_table_name} (plugin_name #{type_to_sql(:string)}, version #{type_to_sql(:string)})"
      plugins_and_versions = select_all("SELECT plugin_name, version from #{Desert::PluginMigrations::Migrator.schema_info_table_name}")
      plugins_and_versions.each do |plugin_data|
        plugin_name, version = plugin_data["plugin_name"], plugin_data["version"]
        plugin = Desert::Manager.find_plugin(plugin_name)
        migration_versions = Dir["#{plugin.migration_path}/*.rb"].map do |path|
          File.basename(path, ".rb")
        end.select do |migration|
          # Make sure versions don't start with zero, or Integer will interpret them as octal
          version_from_table_stripped = version.sub(/^0*/, '')
          migration_version_stripped = migration.split("_").first.sub(/^0*/, '')
          Integer(migration_version_stripped) <= Integer(version_from_table_stripped)
        end
        migration_versions.each do |migration_version|
          version = Integer(migration_version.split("_").first.sub(/^0*/, ''))
          insert_sql = ActiveRecord::Base.send(:sanitize_sql, [
            "INSERT INTO #{Desert::PluginMigrations::Migrator.schema_migrations_table_name}(plugin_name, version) VALUES(?, ?)",
            plugin_name,
            version
          ])
          execute insert_sql
          cleanup_sql = ActiveRecord::Base.send(:sanitize_sql, [
            "DELETE FROM #{Desert::PluginMigrations::Migrator.schema_info_table_name} WHERE plugin_name = ? AND version = ?",
            plugin_name,
            version
          ])
          execute cleanup_sql
        end
      end
    rescue ActiveRecord::StatementInvalid
      # Schema has been initialized
    end
  end
  alias_method_chain :initialize_schema_migrations_table, :plugins
end