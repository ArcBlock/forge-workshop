defmodule ForgeWorkshopWeb.Router do
  use ForgeWorkshopWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", ForgeWorkshopWeb do
    pipe_through(:browser)
    get("/", DidController, :index)
    get("/app", DidController, :step1)
    post("/did", DidController, :create_did)
    get("/did", DidController, :show)
    post("/did/app", DidController, :upsert_app_state)
    post("/did/claims", DidController, :upsert_claims)
    get("/did/claims", DidController, :reselect_claims)
    post("/did/start_over", DidController, :start_over)

    get("/wallet", WalletController, :index)
    get("/wallet/auth", WalletController, :request_auth)
    post("/wallet/auth", WalletController, :response_auth)

    resources("/demo", DemoController)
    resources("/tx", TxController)
    put("/tx", TxController, :create)
  end

  scope "/api", ForgeWorkshopWeb do
    pipe_through(:api)
    get("/auth", AuthController, :request_auth)
    post("/auth", AuthController, :response_auth)
    get("/agreement/:id", AgreementController, :get)

    post("/wallet/recover", WalletController, :create_wallet)
    get("/wallet/:addr", WalletController, :wallet_state)
  end

  scope "/workflow", ForgeWorkshopWeb do
    pipe_through(:api)

    # DID auth workflow
    # The QR code endpoint to start the swap
    get("/auth", WkAuthController, :start)
    # The endpoint to let user return user addr
    post("/auth/authprincipal", WkAuthController, :auth_principal)
    # The endpoint to let user return swap addr
    post("/auth/returnclaims", WkAuthController, :return_claims)

    # Poke workflow
    # The QR code endpoint to start the swap
    get("/poke/:id/", PokeController, :start)
    # The endpoint to let user return user addr
    post("/poke/:id/authprincipal", PokeController, :auth_principal)
    # The endpoint to let user return swap addr
    post("/poke/:id/returnsig", PokeController, :return_sig)

    # Transfer workflow
    # The QR code endpoint to start the swap
    get("/transfer/:id/", TransferController, :start)
    # The endpoint to let user return user addr
    post("/transfer/:id/authprincipal", TransferController, :auth_principal)
    # The endpoint to let user return swap addr
    post("/transfer/:id/returnsig", TransferController, :return_sig)
    # The endpoint to let user return assets
    post("/transfer/:id/returnasset", TransferController, :return_asset)

    # Exchange workflow
    # The QR code endpoint to start the swap
    get("/exchange/:id/", ExchangeController, :start)
    # The endpoint to let user return user addr
    post("/exchange/:id/authprincipal", ExchangeController, :auth_principal)
    # The endpoint to let user return swap addr
    post("/exchange/:id/returnsig", ExchangeController, :return_sig)
    # The endpoint to let user return assets
    post("/exchange/:id/returnasset", ExchangeController, :return_asset)

    # UpdateAsset workflow
    # The QR code endpoint to start the swap
    get("/updateasset/:id/", UpdateAssetController, :start)
    # The endpoint to let user return user addr
    post("/updateasset/:id/authprincipal", UpdateAssetController, :auth_principal)
    # The endpoint to let user return swap addr
    post("/updateasset/:id/returnsig", UpdateAssetController, :return_sig)
    # The endpoint to let user return assets
    post("/updateasset/:id/returnasset", UpdateAssetController, :return_asset)

    # ConsumeAsset workflow
    # The QR code endpoint to start the swap
    get("/consumeasset/:id/", ConsumeAssetController, :start)
    # The endpoint to let user return user addr
    post("/consumeasset/:id/authprincipal", ConsumeAssetController, :auth_principal)
    # The endpoint to let user return swap addr
    post("/consumeasset/:id/returnsig", ConsumeAssetController, :return_sig)
    # The endpoint to let user return assets
    post("/consumeasset/:id/returnasset", ConsumeAssetController, :return_asset)

    # ProofOfHolding workflow
    # The QR code endpoint to start the swap
    get("/poh/:id/", PohController, :start)
    # The endpoint to let user return user addr
    post("/poh/:id/authprincipal", PohController, :auth_principal)
    # The endpoint to let user return assets
    post("/poh/:id/returnasset", PohController, :return_asset)
  end
end
