export PORT=9000
export SECRET_KEY_BASE=696e15a5a9ab308ce2b4279732f5104eaf957ea0e377baaaf050f70c419dbca1778fcfd462ef32cf18cf2d8c746cb531f15caad8be41476f168213fedba1887e
export DB_USER=postgres
export DB_PASS=postgres
export DB_NAME=dojo_dev
export DB_HOST=localhost
export URL_HOST=localhost
export STOCKFISH_PATH=$(find /home -name stockfish_15.1_x64_bmi2 -print -quit)
git add .
git commit -m "deploy script changes, work on home res"
# MIX_ENV=dev mix phx.server 
# MIX_ENV=prod elixir --erl "-detached" -S mix phx.server