defmodule AbtDidWorkshop.Plugs.VerifySig do
  @moduledoc false

  import Plug.Conn
  import Phoenix.Controller

  alias AbtDidWorkshop.Util

  def init(_) do
  end

  def call(%Plug.Conn{body_params: %{"userPk" => user_pk, "userInfo" => user_info}} = conn, _) do
    pk_bin = Util.str_to_bin(user_pk)

    if AbtDid.Signer.verify(user_info, pk_bin) do
      body = Util.get_body(user_info)

      conn
      |> assign(:user, %{address: Util.did_to_address(body["iss"]), pk: pk_bin})
      |> assign(:iat, body["iat"])
      |> assign(:nbf, body["nbf"])
      |> assign(:exp, body["exp"])
      |> assign(:claims, Map.get(body, "requestedClaims", []))
      |> assign(:params, Map.get(body, "params", %{}))
    else
      conn
      |> json(%{error: "The signature of the user info does not match the public key."})
      |> halt()
    end
  end

  def call(conn, _) do
    conn
    |> json(%{error: "Request must have userPk and userInfo."})
    |> halt()
  end
end
