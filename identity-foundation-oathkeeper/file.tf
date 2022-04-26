resource "local_file" "oathkeeper_access_rules" {
  filename = "${path.module}/access-rules.yaml"
  content = yamlencode([
    {
      id = "ory:account:anonymous"
      upstream = {
        url = var.identity_foundation_account_public_url
      }
      match = {
        url = "${var.oathkeeper_proxy_public_url}/account/<**>"
        methods = [
          "GET",
          "POST"
        ]
      }
      authenticators = [
        {
          handler = "anonymous"
        }
      ]
      authorizer = {
        handler = "allow"
      }
      mutators = [
        {
          handler = "hydrator"
        }
      ]
    },
    {
      id = "ory:app:protected"
      upstream = {
        url = var.identity_foundation_app_public_url
      }
      match = {
        url = "${var.oathkeeper_proxy_public_url}/app/<{home,api/*,favicon.ico,_next/static/**.css,_next/static/**.js,**.svg}>",
        methods = [
          "GET"
        ]
      }
      authenticators = [
        {
          handler = "cookie_session"
        }
      ]
      authorizer = {
        handler = "allow"
      }
      mutators = [
        {
          handler = "hydrator"
        }
      ]
      errors = [
        {
          handler = "redirect"
        }
      ]
    }
  ])
}

resource "local_sensitive_file" "oathkeeper_config" {
  filename = "${path.module}/.oathkeeper.yaml"
  content = yamlencode({
    version = "v0.38.4-beta.1"
    log = {
      level  = "debug"
      format = "json"
    }
    serve = {
      proxy = {
        cors = {
          enabled = true
          allowed_origins = [
            "*"
          ]
          allowed_methods = [
            "POST",
            "GET",
            "PUT",
            "PATCH",
            "DELETE"
          ]
          allowed_headers = [
            "Authorization",
            "Content-Type"
          ]
          exposed_headers = [
            "Content-Type"
          ]
          allow_credentials = true
          debug             = true
        }
      }
    }
    errors = {
      fallback = [
        "json"
      ]
      handlers = {
        redirect = {
          enabled = true
          config = {
            to = "${var.oathkeeper_proxy_public_url}/account/flow/login.php?return_to=${var.oathkeeper_proxy_public_url}/app/home"
            when = [
              {
                error = [
                  "unauthorized",
                  "forbidden"
                ]
                request = {
                  header = {
                    accept = [
                      "text/html"
                    ]
                  }
                }
              }
            ]
          }
        }
        json = {
          enabled = true
          config = {
            verbose = true
          }
        }
      }
    }
    access_rules = {
      matching_strategy = "glob"
      repositories      = var.oathkeeper_access_rules_repositories
    }
    authenticators = {
      anonymous = {
        enabled = true
        config = {
          subject = "guest"
        }
      }
      cookie_session = {
        enabled = true
        config = {
          check_session_url = "${var.identity_foundation_account_public_url}/account/sessions/whoami.php"
          preserve_path     = true
          extra_from        = "@this"
          subject_from      = "identity.id"
          only = [
            "PHPSESSID"
          ]
        }
      }
      noop = {
        enabled = true
      }
    }
    authorizers = {
      allow = {
        enabled = true
      }
    }
    mutators = {
      noop = {
        enabled = true
      }
      hydrator = {
        enabled = true
        config = {
          api = {
            url = var.oathkeeper_google_url
            auth = {
              basic = {
                username = var.oathkeeper_google_username
                password = var.oathkeeper_google_password
              }
            }
          }
        }
        cache = {
          ttl = "3600s"
        }
      }
    }
  })
}
