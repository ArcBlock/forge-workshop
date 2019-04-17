defmodule AbtDidWorkshopWeb.AuthController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{AppState, Plugs.VerifySig, UserDb, Util}

  plug(VerifySig when action in [:response_auth])

  def request_auth(conn, %{"userDid" => did}) do
    user = UserDb.get(did)
    app = AppState.get()

    if user != nil and filled_entire_profile?(app.claims["profile"], user) do
      json(conn, gen_and_sign())
    else
      json(conn, require_auth())
    end
  end

  def request_auth(conn, _),
    do: send_resp(conn, 400, "The request must contain valid DID.")

  def response_auth(conn, _) do
    user = UserDb.get(conn.assigns.user.address)
    app = AppState.get()

    if user != nil and conn.assigns.claims == [] do
      case filled_entire_profile?(app.claims["profile"], user) do
        true ->
          json(conn, %{response: %{result: :ok}})

        false ->
          json(conn, require_auth())
      end
    else
      do_response_auth_add(conn)
    end
  end

  defp do_response_auth_add(conn) do
    case match_claims?(conn.assigns.claims) do
      true ->
        add_user(conn.assigns.user.pk, conn.assigns.user.address, conn.assigns.claims)
        json(conn, %{response: %{result: :ok}})

      false ->
        send_resp(conn, 422, "Authentication failed.")
    end
  end

  defp add_user(pk, did, claims) do
    user = %{
      did: did,
      pk: pk |> Multibase.encode!(:base58_btc),
      profile: get_profile(claims),
      agreement: get_agreement(claims)
    }

    UserDb.add(user)

    socket = UserDb.get_socket()
    Drab.Live.poke(socket, users: UserDb.get_all())
    Drab.Core.exec_js(socket, "$(document).ready(function(){$('.collapsible').collapsible();});")
  end

  defp match_claims?(claims) do
    expected = AppState.get().claims["profile"]
    actual = get_profile(claims)
    check_profile(expected, actual)
  end

  defp get_profile(claims) do
    claims
    |> Enum.filter(fn claim -> claim["type"] == "profile" end)
    |> List.first()
    |> Kernel.||(%{})
    |> Map.delete("type")
    |> Map.delete("meta")
  end

  defp get_agreement(claims) do
    claims
    |> Enum.filter(fn c -> c["type"] == "agreement" end)
  end

  defp check_profile([], _), do: true

  defp check_profile(expected, actual) do
    Enum.reduce(expected, true, fn claim, acc -> acc and check_profile_item(claim, actual) end)
  end

  defp check_profile_item(_, nil), do: false

  defp check_profile_item(claim_id, actual) do
    case actual[claim_id] do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  defp require_auth do
    gen_claims()
    |> gen_and_sign()
  end

  defp gen_and_sign(claims \\ []) do
    state = AppState.get()

    extra = %{
      url: Util.get_callback() <> "auth/",
      action: "responseAuth",
      requestedClaims: claims,
      appInfo: AppState.get_info(state)
    }

    %{
      appPk: state.pk,
      authInfo: AbtDid.Signer.gen_and_sign(state.did, Multibase.decode!(state.sk), extra)
    }
  end

  defp gen_claims do
    state = AppState.get()
    profile_claim = gen_profile(state.claims["profile"])
    agreement_claims = gen_agreement(state.claims["agreements"])
    profile_claim ++ agreement_claims
  end

  defp gen_profile([]), do: []

  defp gen_profile(profile) do
    [
      %{
        type: "profile",
        meta: %{
          description: "Please provide your profile information."
        },
        items: profile
      }
    ]
  end

  defp gen_agreement([]), do: []

  defp gen_agreement(agreements) when is_list(agreements) do
    Enum.map(agreements, &gen_agreement/1)
  end

  defp gen_agreement(id) do
    :agreement
    |> AbtDidWorkshop.Util.config()
    |> Enum.filter(fn agr -> agr.meta.id == id end)
    |> List.first()
    |> Map.update!(:uri, &Util.get_agreement_uri/1)
    |> Map.delete(:content)
  end

  defp filled_entire_profile?(profile, user) do
    Enum.all?(profile, fn claim_id -> Map.get(user, claim_id) != nil end)
  end
end
