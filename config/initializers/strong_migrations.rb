# NOTE: strong_migrations only runs its safety checks against PostgreSQL, MySQL,
# and MariaDB. This app uses SQLite, so the checks are inert here (you'll see an
# "Unsupported adapter: SQLite" notice otherwise). We keep the gem configured so
# the safe-migration patterns and this config carry over to a production-grade
# database. Silence the per-migration warning in the meantime.
StrongMigrations.skip_database(:primary)

# Mark existing migrations as safe. The initial create_books migration predates
# strong_migrations, so we grandfather it; every migration after it is checked.
StrongMigrations.start_after = 20260704152532

# Set timeouts for migrations
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour

# Analyze tables after indexes are added
# Outdated statistics can sometimes hurt performance
StrongMigrations.auto_analyze = true

# Set the version of the production database
# so the right checks are run in development
# StrongMigrations.target_version = 18

# Add custom checks
# StrongMigrations.add_check do |method, args|
#   if method == :add_index && args[0].to_s == "users"
#     stop! "No more indexes on the users table"
#   end
# end
