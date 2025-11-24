class CreateJobs < ActiveRecord::Migration[7.1]
  def change
    create_table :jobs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'pending', null: false
      t.json :payload, null: false
      t.string :idempotency_key
      t.integer :retry_count, default: 0, null: false
      t.integer :max_retries, default: 3, null: false
      t.datetime :leased_at
      t.string :leased_by
      t.text :error_message
      t.string :trace_id
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    # Indexes for efficient querying
    add_index :jobs, :status
    add_index :jobs, :idempotency_key, unique: true
    add_index :jobs, [:user_id, :status]
    add_index :jobs, :leased_at
    add_index :jobs, :trace_id
  end
end
