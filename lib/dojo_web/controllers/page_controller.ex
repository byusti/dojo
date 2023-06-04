defmodule DojoWeb.PageController do
  alias Phoenix.Token
  use DojoWeb, :controller
  require Logger

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, _params) do
    conn =
      Plug.Conn.put_resp_header(
        conn,
        "cache-control",
        "no-cache, no-store, must-revalidate"
      )

    case get_session(conn, :user_token) do
      nil ->
        user_id = UUID.string_to_binary!(UUID.uuid1())
        user_id = Base.url_encode64(user_id, padding: false)

        token = Token.sign(conn, "user auth", user_id)
        conn = put_session(conn, :user_token, token)

        render(conn, "home.html",
          layout: {DojoWeb.LayoutView, "home_layout.html"},
          user_token: token
        )

      user_token ->
        render(conn, "home.html",
          layout: {DojoWeb.LayoutView, "home_layout.html"},
          user_token: user_token
        )
    end
  end

  def accept(conn, %{"gameid" => game_id}) do
    case Registry.lookup(GameRegistry, game_id) do
      [] ->
        info = game_id
        render(conn, "room_error.html", info: info)

      [{pid, _}] ->
        game_state = Dojo.Game.get_state(pid)

        case game_state.invite_accepted do
          true ->
            render_room_error(conn)

          false ->
            user_token = get_session(conn, :user_token)

            case game_state.white_user_id == user_token or game_state.black_user_id == user_token do
              true ->
                render_room_error(conn)

              false ->
                Dojo.Game.accept_invite(pid)

                case {game_state.white_user_id, game_state.black_user_id} do
                  {nil, nil} ->
                    raise "Game must have at least one player already in it"

                  {nil, _} ->
                    Dojo.Game.set_white_user_id(pid, user_token)

                  {_, nil} ->
                    Dojo.Game.set_black_user_id(pid, user_token)

                  _ ->
                    raise "Game already has two players"
                end

                token = Token.sign(conn, "game auth", game_id)
                conn = put_resp_cookie(conn, "game_token", token)

                DojoWeb.Endpoint.broadcast!("room:" <> game_id, "invite_accepted", %{})

                redirect(conn, to: Routes.page_path(conn, :room, game_id))
            end
        end
    end
  end

  def room(conn, %{"gameid" => url_game_id}) do
    pid =
      case Registry.lookup(GameRegistry, url_game_id) do
        [] ->
          info = url_game_id
          render(conn, "room_error.html", info: info)

        [{pid, _}] ->
          pid
      end

    game_state = Dojo.Game.get_state(pid)

    {conn, user_token} =
      case get_session(conn, :user_token) do
        nil ->
          user_id = UUID.string_to_binary!(UUID.uuid1())
          user_id = Base.url_encode64(user_id, padding: false)

          token = Token.sign(conn, "user auth", user_id)
          conn = put_session(conn, :user_token, token)
          {conn, token}

        user_token ->
          {conn, user_token}
      end

    conn = fetch_cookies(conn)

    case game_state.game_type do
      :friend ->
        handle_friend_room(conn, game_state, user_token)

      :ai ->
        handle_ai_room(conn, game_state, url_game_id)
    end
  end

  def handle_friend_room(conn, game_state, user_token) do
    case game_state.invite_accepted do
      true ->
        case game_state.white_user_id == user_token or game_state.black_user_id == user_token do
          true ->
            conn =
              Plug.Conn.put_resp_header(
                conn,
                "cache-control",
                "no-cache, no-store, must-revalidate"
              )

            game_token = conn.cookies["game_token"]

            game_status =
              case game_state.status do
                :continue ->
                  "continue"

                {_, _, _} ->
                  Atom.to_string(elem(game_state.status, 1))

                {_, _} ->
                  Enum.map(Tuple.to_list(game_state.status), fn x -> Atom.to_string(x) end)
              end

            {white_time_ms, black_time_ms} =
              case game_state.time_control do
                :real_time ->
                  clock_state = Dojo.Clock.get_clock_state(game_state.clock_pid)
                  white_time_ms = clock_state.white_time_milli
                  black_time_ms = clock_state.black_time_milli
                  {white_time_ms, black_time_ms}

                _ ->
                  {nil, nil}
              end

            color =
              case {game_state.white_user_id == user_token,
                    game_state.black_user_id == user_token} do
                {true, false} -> :white
                {false, true} -> :black
                _ -> raise "User is not a player in this game"
              end

            render(conn, "room.html",
              layout: {DojoWeb.LayoutView, "room_layout.html"},
              fen: game_state.fen,
              color: color,
              game_type: game_state.game_type,
              invite_accepted: game_state.invite_accepted,
              minutes: game_state.minutes,
              increment: game_state.increment,
              dests: DojoWeb.Util.repack_dests(game_state.dests) |> Jason.encode!([]),
              white_clock: white_time_ms,
              black_clock: black_time_ms,
              game_token: game_token,
              game_status: game_status
            )

          false ->
            render_room_error(conn)
        end

      false ->
        case game_state.white_user_id == user_token or game_state.black_user_id == user_token do
          true ->
            render(conn, "friend_pending.html",
              layout: {DojoWeb.LayoutView, "friend_pending_layout.html"},
              game_token: conn.cookies["game_token"]
            )

          false ->
            render(conn, "friend_invite.html",
              layout: {DojoWeb.LayoutView, "friend_invite_layout.html"},
              game_id: game_state.game_id
            )
        end
    end
  end

  def handle_ai_room(conn, game_state, url_game_id) do
    game_token = conn.cookies["game_token"]

    case Token.verify(conn, "game auth", game_token, max_age: 60 * 60 * 24 * 365) do
      {:ok, game_id} ->
        case game_id == url_game_id do
          true ->
            conn =
              Plug.Conn.put_resp_header(
                conn,
                "cache-control",
                "no-cache, no-store, must-revalidate"
              )

            {white_time_ms, black_time_ms} =
              case game_state.time_control do
                :real_time ->
                  clock_state = Dojo.Clock.get_clock_state(game_state.clock_pid)
                  white_time_ms = clock_state.white_time_milli
                  black_time_ms = clock_state.black_time_milli
                  {white_time_ms, black_time_ms}

                _ ->
                  {nil, nil}
              end

            # Dojo.Clock.get_clock_state(game_state.clock_pid)

            game_status =
              case game_state.status do
                :continue ->
                  "continue"

                {_, _, _} ->
                  Atom.to_string(elem(game_state.status, 1))

                {_, _} ->
                  Enum.map(Tuple.to_list(game_state.status), fn x -> Atom.to_string(x) end)
              end

            render(conn, "room.html",
              layout: {DojoWeb.LayoutView, "room_layout.html"},
              fen: game_state.fen,
              color: game_state.color,
              game_type: game_state.game_type,
              invite_accepted: game_state.invite_accepted,
              minutes: game_state.minutes,
              increment: game_state.increment,
              dests: DojoWeb.Util.repack_dests(game_state.dests) |> Jason.encode!([]),
              white_clock: white_time_ms,
              black_clock: black_time_ms,
              game_token: game_token,
              game_status: game_status
            )

          false ->
            render_room_error(conn)
        end

      _ ->
        render_room_error(conn)
    end
  end

  def render_room_error(conn) do
    render(conn, "room_error.html",
      layout: {DojoWeb.LayoutView, "room_layout.html"},
      info: "catastrophic disaster..."
    )
  end
end
