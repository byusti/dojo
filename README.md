Instructions for setting up the repo:

```
# Initial setup

mix deps.get --only prod

MIX_ENV=prod mix compile

# Compile assets

MIX_ENV=prod mix assets.deploy

# Custom tasks (like DB migrations)

MIX_ENV=prod mix ecto.migrate

# Generate release files

mix phx.gen.release

# ...
scp _build/dev/rel/my_app-0.1.0.tar.gz $PROD:/srv/my_app.tar.gz
ssh $PROD "untar -xz /srv/my_app.tar.gz"
ssh $PROD "/srv/my_app/bin/my_app start_daemon

# Finally run the server

PORT=4001 MIX_ENV=prod mix phx.server
```

go into the /assets directory and install npm packages:

npm install

return to root directory and run:

mix deps.get

make sure to place stockfish executable at the root of the server directory with name "stockfish"

start server with:

mix phx.server