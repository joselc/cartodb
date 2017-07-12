module Carto
  class TableRegister
    def initialize(data_import, user, table_name)
      @data_import = data_import
      @user = user
      @table_name = table_name
    end

    def register
      table = build_table

      metadata_visualization = @data_import.metadata_visualization
      if metadata_visualization
        copy_visualization_metedata_to_table(metadata_visualization, table)
      end

      table.save
      table.optimize
      table.map.recalculate_bounds!
    end

    private

    def build_table
      table = Table.new
      table.user_id = @user.user

      # TODO: remember to set the Table class name in a sounder way once Table
      # has been refactored.
      table.instance_eval { self[:name] = @table_name }

      table.migrate_existing_table = @table_name
      table.data_import_id = @data_import.id
      table
    end

    def copy_visualization_metedata_to_table(visualization, table)
      table.description = visualization.description
      table.set_tag_array(visualization.tags)
    end
  end
end
