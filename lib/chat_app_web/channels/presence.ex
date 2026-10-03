defmodule ChatAppWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://phoenix.hexdocs.pm/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :chat_app,
    pubsub_server: ChatApp.PubSub
end
