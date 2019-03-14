defmodule AbtDidWorkshopWeb.AuthController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.{AppState, Plugs.VerifySig, UserDb, Util}

  plug(VerifySig when action in [:response_auth])

  def request_auth(conn, %{"userDid" => did}) do
    user = UserDb.get(did)

    if user != nil and filled_all_claims?(user) do
      json(conn, gen_and_sign())
    else
      json(conn, request_reg())
    end
  end

  def request_auth(conn, _),
    do: send_resp(conn, 400, "The request must contain valid DID.")

  def response_auth(conn, _) do
    user_did = conn.assigns.did
    user = UserDb.get(user_did)

    if user != nil and conn.assigns.claims == [] do
      case filled_all_claims?(user) do
        true ->
          json(conn, %{response: :ok})

        false ->
          json(conn, request_reg())
      end
    else
      do_response_auth_add(conn)
    end
  end

  defp do_response_auth_add(conn) do
    case match_claims?(conn.assigns.claims) do
      true ->
        add_user(conn.assigns.pk, conn.assigns.did, conn.assigns.claims)
        json(conn, %{response: :ok})

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
    expected = AppState.get().profile
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

  defp request_reg do
    claims = gen_claims()
    callback = Util.get_callback() <> "auth/"

    gen_and_sign(%{
      url: callback,
      action: "responseAuth",
      requestedClaims: claims,
      appInfo: AppState.get().info
    })
  end

  defp gen_and_sign(extra \\ %{}) do
    state = AppState.get()
    did_type = AbtDid.get_did_type(state.did)
    auth_info = AbtDid.Signer.gen_and_sign(did_type, state.sk, extra)

    %{
      appPk: state.pk |> Multibase.encode!(:base58_btc),
      authInfo: auth_info
    }
  end

  defp gen_claims do
    profile_claim = gen_profile()
    agreement_claims = gen_agreement()
    profile_claim ++ agreement_claims
  end

  defp gen_profile do
    case AppState.get().profile do
      [] ->
        []

      profile ->
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
  end

  defp gen_agreement do
    case AppState.get().agreements do
      [] -> []
      agreements -> Enum.map(agreements, &gen_agreement/1)
    end
  end

  defp gen_agreement(id) do
    :abt_did_workshop
    |> Application.get_env(:agreement, [])
    |> Enum.filter(fn agr -> agr.meta.id == id end)
    |> List.first()
    |> Map.update!(:uri, &Util.get_agreement_uri/1)
    |> Map.delete(:content)
  end

  defp filled_all_claims?(user) do
    app_sate = AppState.get()
    Enum.all?(app_sate.profile, fn claim_id -> Map.get(user, claim_id) != nil end)
  end
end
