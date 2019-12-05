defmodule ForgeWorkshopWeb.AuthController do
  use ForgeWorkshopWeb, :controller
  use Hyjal, router: ForgeWorkshopWeb.Router

  require Logger

  alias ForgeWorkshop.{AppState, ClaimUtil, UserDb, Util}
  alias Hyjal.Plugs.VerifyAuthPrincipal
  alias Hyjal.Claims.AuthPrincipal

  plug(VerifyAuthPrincipal when action != :start)

  @profile_desc "Please provide your profile information."

  @impl AuthFlow
  def start(conn, _params) do
    info = get_info(conn)
    claim = %AuthPrincipal{description: "Please set the authentication principal."}
    reply_with_info(conn, [claim], __MODULE__, :auth_principal, [], info)
  end

  @impl AuthFlow
  def auth_principal(conn, _params) do
    app = AppState.get()
    info = get_info(conn)

    case check_user_in_db(conn) do
      {true, true} ->
        reply_with_info(conn, :ok, info)

      _ ->
        profile = ClaimUtil.gen_profile_claim(@profile_desc, app.claims["profile"])
        agreements = ClaimUtil.gen_agreement_claims(get_expected_agreements())
        reply_with_info(conn, profile ++ agreements, __MODULE__, :return_claims, [], info)
    end
  end

  def return_claims(conn, _params) do
    info = get_info(conn)

    case check_claims(conn) do
      {true, true} ->
        profile = ClaimUtil.find_profile_claim(conn.assigns.claims)
        agreements = ClaimUtil.find_agreement_claims(conn.assigns.claims)
        add_user(conn.assigns.auth_principal, profile, agreements)
        reply_with_info(conn, :ok, info)

      _ ->
        reply_with_info(conn, :error, "Authentication failed.", info)
    end
  end

  defp add_user(user, profile, agreements) do
    user = %{
      address: user.address,
      pk: user.pk,
      profile: profile.data,
      agreements: agreements
    }

    UserDb.add(user)
    socket = UserDb.get_socket()
    Drab.Live.poke(socket, users: UserDb.get_all())
    Drab.Core.exec_js(socket, "$(document).ready(function(){$('.collapsible').collapsible();});")
  end

  defp check_user_in_db(conn) do
    case UserDb.get(conn.assigns.auth_principal.address) do
      nil ->
        {false, false}

      user ->
        profile = user.profile
        agreements = user.agreements
        {validate_profile(profile), validate_agreements(agreements, user)}
    end
  end

  defp check_claims(conn) do
    profile = ClaimUtil.find_profile_claim(conn.assigns.claims)
    agreements = ClaimUtil.find_agreement_claims(conn.assigns.claims)
    user = conn.assigns.auth_principal
    {validate_profile(profile.data), validate_agreements(agreements, user)}
  end

  defp validate_profile(actual) when is_map(actual) do
    app = AppState.get()
    expected = app.claims["profile"]
    Enum.all?(expected, fn profile_item -> Map.get(actual, profile_item) != nil end)
  end

  defp get_expected_agreements() do
    app = AppState.get()

    :agreement
    |> ForgeWorkshop.Util.config()
    |> Enum.filter(fn %{meta: %{id: id}} -> id in app.claims["agreements"] end)
  end

  defp validate_agreements(actual, user) do
    get_expected_agreements()
    |> Enum.all?(fn expected -> validate_agreement(expected, actual, user) end)
  end

  defp validate_agreement(expected, actual, user) do
    act = Enum.find(actual, fn %{meta: %{"id" => id}} -> expected.meta.id == id end)

    act != nil and act.digest == Util.str_to_bin(expected.digest) and act.agreed and
      match_sig(act.digest, act.sig, user)
  end

  defp match_sig(digest, sig, user) do
    signer =
      case AbtDid.get_did_type(user.address) do
        %{key_type: :ed25519} -> %Mcrypto.Signer.Ed25519{}
        %{key_type: :secp256k1} -> %Mcrypto.Signer.Secp256k1{}
      end

    Mcrypto.verify(signer, digest, sig, user.pk)
  end

  defp get_info(conn) do
    demo = AppState.get()
    Util.get_hyjal_info(conn, demo)
  end
end
