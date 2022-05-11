resource "local_sensitive_file" "jwks" {
  filename = "${path.module}/id_token.jwks.json"
  content  = jsonencode(jsondecode(data.google_kms_secret.jwks_keys.plaintext))
}

resource "local_file" "app_swagger" {
  filename = "${path.module}/app.swagger.json"
  content = jsonencode({
    swagger = "2.0"
    info = {
      title   = "Identity Foundation App"
      version = "1.0.0"
    }
    schemes = [
      "https"
    ]
    produces = [
      "application/json"
    ]
    paths = {
      "/{subpath=**}" = {
        for method in ["get", "post", "put", "delete"] :
        method => {
          summary     = "identity-foundation-app"
          operationId = "identity-foundation-app-${method}"
          x-google-backend = {
            address          = local.identity_foundation_app_run_url
            path_translation = "APPEND_PATH_TO_ADDRESS"
          }
          responses = {
            default = {
              description = "Response"
            }
          }
          security = [
            { oathkeeper = [] }
          ]
          parameters = [
            {
              in       = "path"
              name     = "subpath"
              type     = "string"
              required = true
            }
          ]
        }
      }
    }
    securityDefinitions = {
      oathkeeper = {
        authorizationUrl  = ""
        flow              = "implicit"
        type              = "oauth2"
        x-google-issuer   = var.oathkeeper_api_public_url
        x-google-jwks_uri = "${var.oathkeeper_api_public_url}/.well-known/jwks.json"
        x-google-jwt-locations = [
          {
            header       = "Authorization"
            value_prefix = "Bearer "
          }
        ]
      }
    }
  })
}

resource "local_file" "account_swagger" {
  filename = "${path.module}/account.swagger.json"
  content = jsonencode({
    swagger = "2.0"
    info = {
      title   = "Identity Foundation Account API"
      version = "1.0.0"
    }
    schemes = [
      "https"
    ]
    produces = [
      "application/json"
    ]
    paths = {
      "/{subpath=**}" = {
        for method in ["get"] :
        method => {
          summary     = "identity-foundation-account"
          operationId = "identity-foundation-account-${method}"
          x-google-backend = {
            address          = local.identity_foundation_account_run_url
            path_translation = "APPEND_PATH_TO_ADDRESS"
          }
          responses = {
            default = {
              description = "Response"
            }
          }
          security = [
            { oathkeeper = [] }
          ]
          parameters = [
            {
              in       = "path"
              name     = "subpath"
              type     = "string"
              required = true
            }
          ]
        }
      }
    }
    securityDefinitions = {
      oathkeeper = {
        authorizationUrl  = ""
        flow              = "implicit"
        type              = "oauth2"
        x-google-issuer   = var.oathkeeper_api_public_url
        x-google-jwks_uri = "${var.oathkeeper_api_public_url}/.well-known/jwks.json"
        x-google-jwt-locations = [
          {
            header       = "Authorization"
            value_prefix = "Bearer "
          }
        ]
      }
    }
  })
}
