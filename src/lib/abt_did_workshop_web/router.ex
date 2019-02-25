defmodule AbtDidWorkshopWeb.Router do
  use AbtDidWorkshopWeb, :router

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

  scope "/", AbtDidWorkshopWeb do
    pipe_through(:browser)
    get("/", DidController, :index)
    post("/did", DidController, :create_did)
    get("/did", DidController, :show)
    post("/did/claims", DidController, :update_claims)
    get("/did/claims", DidController, :continue)
    get("/did/regenerate", DidController, :regenerate)

    get("/wallet", WalletController, :index)
    get("/wallet/auth", WalletController, :request_auth)
    post("/wallet/auth", WalletController, :response_auth)
  end

  scope "/api", AbtDidWorkshopWeb do
    pipe_through(:api)
    get("/auth", AuthController, :request_auth)
    post("/auth", AuthController, :response_auth)
    get("/agreement/:id", AgreementController, :get)

    # get("/cert", CertController, :index)
    post("/cert/recover-wallet", CertController, :recover_wallet)
    post("/cert/request-issue", CertController, :request_issue)
    post("/cert/response-issue", CertController, :response_issue)
    post("/cert/request-reward", CertController, :request_reward)
    post("/cert/response-reward", CertController, :response_reward)
  end
end
