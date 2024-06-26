defmodule DojoWeb.SetupController do
  require Logger
  alias Dojo.UserTracker
  alias Dojo.GameState
  alias Dojo.Stockfish
  alias Phoenix.Token
  use DojoWeb, :controller

  def setup_game(conn, %{
        "color" => color,
        "time-control" => time_control,
        "minutes" => minutes,
        "increment" => increment,
        "_csrf_token" => csrf_token
      }) do
    case csrf_token == conn.cookies["_csrf_token"] do
      true ->
        game_id = UUID.string_to_binary!(UUID.uuid1())
        game_id = Base.url_encode64(game_id, padding: false)

        user_token = get_session(conn, :user_token)

        user_id =
          case Token.verify(conn, "user auth", user_token) do
            {:ok, user_id} -> user_id
            _ -> raise "invalid user token"
          end

        case UserTracker.contains_active_user(user_id) do
          true ->
            active_user = UserTracker.get_active_user(user_id)
            game_state = Dojo.Game.get_state(active_user.game_pid)
            game_type = game_state.game_type
            game_id = game_state.game_id
            invite_accepted = game_state.invite_accepted

            case game_type do
              :open ->
                case invite_accepted do
                  true ->
                    redirect(conn, to: Routes.page_path(conn, :room, game_id))

                  false ->
                    text(conn, "already created open game")
                end

              _ ->
                redirect(conn, to: Routes.page_path(conn, :room, game_id))
            end

          false ->
            {white_user_id, black_user_id} =
              case color do
                "white" ->
                  {user_id, nil}

                "black" ->
                  {nil, user_id}

                _ ->
                  case :rand.uniform(10) do
                    x when x > 5 -> {user_id, nil}
                    _ -> {nil, user_id}
                  end
              end

            {minutes, increment} =
              case time_control do
                "unlimited" ->
                  {nil, nil}

                _ ->
                  minutes =
                    case minutes do
                      "5" -> 5
                      "10" -> 10
                      "15" -> 15
                      "30" -> 30
                      _ -> 5
                    end

                  increment =
                    case increment do
                      "0" -> 0
                      "3" -> 3
                      "5" -> 5
                      "10" -> 10
                      "20" -> 20
                      _ -> 0
                    end

                  {minutes, increment}
              end

            time_control =
              case time_control do
                "real time" -> :real_time
                "unlimited" -> :unlimited
                _ -> raise "invalid time control"
              end

            game_init_state = %GameState{
              game_id: game_id,
              color: color,
              game_type: :open,
              invite_accepted: false,
              white_user_id: white_user_id,
              black_user_id: black_user_id,
              time_control: time_control,
              minutes: minutes,
              increment: increment
            }

            pid =
              Dojo.Game.create_game(game_init_state)
              |> case do
                {nil, error} -> raise error
                pid -> pid
              end

            Dojo.UserTracker.add_active_user(user_id, pid)

            Dojo.GameTracker.add_open_game(game_init_state)

            {minutes, increment} =
              case {minutes, increment} do
                {nil, nil} -> {"inf", "inf"}
                {minutes, increment} -> {minutes, increment}
              end

            DojoWeb.Endpoint.broadcast("home:lobby", "new_game", %{
              game_id: game_id,
              game_creator_id: user_id,
              minutes: minutes,
              increment: increment
            })

            conn
            |> put_resp_content_type("text/plain")
            |> put_resp_header("game_id", game_id)
            |> send_resp(201, "game created")
        end

      false ->
        raise "CSRF token mismatch"
    end
  end

  def setup_friend(conn, %{
        "color" => color,
        "time-control" => time_control,
        "minutes" => minutes,
        "increment" => increment,
        "_csrf_token" => csrf_token
      }) do
    case csrf_token == conn.cookies["_csrf_token"] do
      true ->
        game_id = UUID.string_to_binary!(UUID.uuid1())
        game_id = Base.url_encode64(game_id, padding: false)

        user_token = get_session(conn, :user_token)

        user_id =
          case Token.verify(conn, "user auth", user_token) do
            {:ok, user_id} -> user_id
            _ -> raise "invalid user token"
          end

        case UserTracker.contains_active_user(user_id) do
          true ->
            active_user = UserTracker.get_active_user(user_id)
            game_state = Dojo.Game.get_state(active_user.game_pid)
            game_type = game_state.game_type
            game_id = game_state.game_id
            invite_accepted = game_state.invite_accepted

            case game_type do
              :open ->
                case invite_accepted do
                  true ->
                    redirect(conn, to: Routes.page_path(conn, :room, game_id))

                  false ->
                    redirect(conn, to: Routes.page_path(conn, :index))
                end

              _ ->
                redirect(conn, to: Routes.page_path(conn, :room, game_id))
            end

          false ->
            {white_user_id, black_user_id} =
              case color do
                "white" ->
                  {user_id, nil}

                "black" ->
                  {nil, user_id}

                _ ->
                  case :rand.uniform(10) do
                    x when x > 5 -> {user_id, nil}
                    _ -> {nil, user_id}
                  end
              end

            {minutes, increment} =
              case time_control do
                "unlimited" ->
                  {nil, nil}

                _ ->
                  minutes =
                    case minutes do
                      "5" -> 5
                      "10" -> 10
                      "15" -> 15
                      "30" -> 30
                      _ -> 5
                    end

                  increment =
                    case increment do
                      "0" -> 0
                      "3" -> 3
                      "5" -> 5
                      "10" -> 10
                      "20" -> 20
                      _ -> 0
                    end

                  {minutes, increment}
              end

            time_control =
              case time_control do
                "real time" -> :real_time
                "unlimited" -> :unlimited
                _ -> raise "invalid time control"
              end

            game_init_state = %GameState{
              game_id: game_id,
              color: color,
              game_type: :friend,
              invite_accepted: false,
              white_user_id: white_user_id,
              black_user_id: black_user_id,
              time_control: time_control,
              minutes: minutes,
              increment: increment
            }

            pid =
              Dojo.Game.create_game(game_init_state)
              |> case do
                {nil, error} -> raise error
                pid -> pid
              end

            Dojo.UserTracker.add_active_user(user_id, pid)

            redirect(conn, to: Routes.page_path(conn, :room, game_id))
        end

      false ->
        raise "CSRF token mismatch"
    end
  end

  def setup_ai(conn, %{
        "color" => color,
        "time-control" => time_control,
        "minutes" => minutes,
        "increment" => increment,
        "difficulty" => difficulty,
        "_csrf_token" => csrf_token
      }) do
    case csrf_token == conn.cookies["_csrf_token"] do
      true ->
        user_token = get_session(conn, :user_token)

        user_id =
          case Token.verify(conn, "user auth", user_token) do
            {:ok, user_id} -> user_id
            _ -> raise "invalid user token"
          end

        color =
          case color do
            "white" ->
              "white"

            "black" ->
              "black"

            _ ->
              case :rand.uniform(10) do
                x when x > 5 -> "white"
                _ -> "black"
              end
          end

        time_control =
          case time_control do
            "unlimited" -> :unlimited
            "real time" -> :real_time
            "correspondence" -> :correspondence
            _ -> :unlimited
          end

        difficulty =
          case difficulty do
            "1" -> 1
            "2" -> 2
            "3" -> 3
            "4" -> 4
            "5" -> 5
            "6" -> 6
            "7" -> 7
            "8" -> 8
            _ -> 1
          end

        game_id = UUID.string_to_binary!(UUID.uuid1())
        game_id = Base.url_encode64(game_id, padding: false)

        {white_user_id, black_user_id} =
          case color do
            "white" ->
              {user_id, nil}

            "black" ->
              {nil, user_id}

            _ ->
              case :rand.uniform(10) do
                x when x > 5 -> {user_id, nil}
                _ -> {nil, user_id}
              end
          end

        minutes =
          case minutes do
            "1" -> 1
            "3" -> 3
            "5" -> 5
            "10" -> 10
            "15" -> 15
            "30" -> 30
            _ -> 5
          end

        increment =
          case increment do
            "0" -> 0
            "3" -> 3
            "5" -> 5
            "10" -> 10
            "20" -> 20
            _ -> 0
          end

        game_init_state = %GameState{
          game_id: game_id,
          white_user_id: white_user_id,
          black_user_id: black_user_id,
          color: color,
          game_type: :ai,
          time_control: time_control,
          minutes: minutes,
          increment: increment,
          difficulty: difficulty
        }

        case UserTracker.contains_active_user(user_id) do
          true ->
            active_user = UserTracker.get_active_user(user_id)
            game_state = Dojo.Game.get_state(active_user.game_pid)
            game_type = game_state.game_type
            game_id = game_state.game_id
            invite_accepted = game_state.invite_accepted

            case game_type do
              :open ->
                case invite_accepted do
                  true ->
                    redirect(conn, to: Routes.page_path(conn, :room, game_id))

                  false ->
                    redirect(conn, to: Routes.page_path(conn, :index))
                end

              _ ->
                redirect(conn, to: Routes.page_path(conn, :room, game_id))
            end

          false ->
            pid =
              Dojo.Game.create_game(game_init_state)
              |> case do
                {nil, error} -> raise error
                pid -> pid
              end

            Dojo.UserTracker.add_active_user(user_id, pid)

            Logger.debug("Stockfish count: #{Registry.count(StockfishRegistry)}")

            if Dojo.Game.get_halfmove_clock(pid) == 0 && color == "black" do
              # Dojo.Game.make_move(pid, <<"e2e4">>)
              Registry.lookup(StockfishRegistry, <<"1">>)
              |> case do
                [] ->
                  raise "Stockfish process not found"

                [{stockfish_pid, _}] ->
                  ai_move =
                    Stockfish.find_best_move(stockfish_pid, Dojo.Game.get_fen(pid), difficulty)

                  Dojo.Game.make_move(pid, ai_move)
              end
            end

            redirect(conn, to: Routes.page_path(conn, :room, game_id))
        end

      false ->
        raise "CSRF token does not match"
    end
  end
end
