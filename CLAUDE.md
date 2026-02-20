Update project specific readme with commands on how to run simple things to the project, starting up, running tests etc if they're not present already

Whenever we make changes to @backend/ always run the tests and linter after changes and fix linter errors. Call out the ones you need a human to fix


Do not add more sql schemas, always modify @001_complete_schema.sql to avoid churn and confusion. If we need to, call out that we need to delete all tables and run the schema migration again.

A feature is not complete until it's integrated with ios!


Claude can never run npx convex dev cuz he can't get it right. always ask for the user to run it/