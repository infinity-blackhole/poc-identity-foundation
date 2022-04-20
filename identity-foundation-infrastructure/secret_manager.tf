data "google_secret_manager_secret" "oathkeeper_access_rules" {
  project   = var.google_project
  secret_id = "oathkeeper-access-rules"
}

resource "google_secret_manager_secret_version" "oathkeeper_access_rules" {
  secret = data.google_secret_manager_secret.oathkeeper_access_rules.id
  secret_data = yamlencode([
    {
      id = "ory:account:anonymous",
      upstream = {
        url = var.identity_foundation_account_public_url
      },
      match = {
        url = "${var.oathkeeper_proxy_public_url}/account/<**>",
        methods = [
          "GET",
          "POST"
        ]
      },
      authenticators = [
        {
          handler = "anonymous"
        }
      ],
      authorizer = {
        handler = "allow"
      },
      mutators = [
        {
          handler = "noop"
        }
      ]
    },
    {
      id = "ory:app:protected",
      upstream = {
        url = var.identity_foundation_app_public_url,
      },
      match = {
        url = "${var.oathkeeper_proxy_public_url}/app/<{home,api/*,favicon.ico,_next/static/**.css,_next/static/**.js,**.svg}>",
        methods = [
          "GET"
        ]
      },
      authenticators = [
        {
          handler = "cookie_session"
        }
      ],
      authorizer = {
        handler = "allow"
      },
      mutators = [
        {
          handler = "id_token"
        }
      ],
      errors = [
        {
          handler = "redirect",
          config = {
            to = "${var.oathkeeper_proxy_public_url}/account/flow/login.php"
          }
        }
      ]
    }
  ])
}

data "google_secret_manager_secret" "oathkeeper_config" {
  project   = var.google_project
  secret_id = "oathkeeper-config"
}

resource "google_secret_manager_secret_version" "oathkeeper_config" {
  secret = data.google_secret_manager_secret.oathkeeper_config.id
  secret_data = yamlencode({
    version = "v0.38.4-beta.1",
    log = {
      level  = "debug",
      format = "json"
    },
    serve = {
      proxy = {
        cors = {
          enabled = true,
          allowed_origins = [
            "*"
          ],
          allowed_methods = [
            "POST",
            "GET",
            "PUT",
            "PATCH",
            "DELETE"
          ],
          allowed_headers = [
            "Authorization",
            "Content-Type"
          ],
          exposed_headers = [
            "Content-Type"
          ],
          allow_credentials = true,
          debug             = true
        }
      }
    },
    errors = {
      fallback = [
        "json"
      ],
      handlers = {
        redirect = {
          enabled = true,
          config = {
            to = "${var.oathkeeper_proxy_public_url}/account/flow/login.php?return_to=${var.oathkeeper_proxy_public_url}/app/home",
            when = [
              {
                error = [
                  "unauthorized",
                  "forbidden"
                ],
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
        },
        json = {
          enabled = true,
          config = {
            verbose = true
          }
        }
      }
    },
    access_rules = {
      matching_strategy = "glob",
      repositories = [
        "file:///secrets/oathkeeper-access-rules/access-rules.yaml"
      ]
    },
    authenticators = {
      anonymous = {
        enabled = true,
        config = {
          subject = "guest"
        }
      },
      cookie_session = {
        enabled = true,
        config = {
          check_session_url = "${var.identity_foundation_account_public_url}/account/sessions/whoami.php",
          preserve_path     = true,
          extra_from        = "@this",
          subject_from      = "identity.id",
          only = [
            "PHPSESSID"
          ]
        }
      },
      noop = {
        enabled = true
      }
    },
    authorizers = {
      allow = {
        enabled = true
      }
    },
    mutators = {
      noop = {
        enabled = true
      },
      id_token = {
        enabled = true,
        config = {
          issuer_url = "${var.oathkeeper_proxy_public_url}/",
          jwks_url   = "file:///secrets/idtoken-jwks/id_token.jwks.json",
          claims     = "{\"session\": {{ .Extra | toJson }}}"
        }
      }
    }
  })
}

data "google_secret_manager_secret" "idtoken_jwks" {
  project   = var.google_project
  secret_id = "idtoken-jwks"
}

resource "google_secret_manager_secret_version" "idtoken_jwks" {
  secret = data.google_secret_manager_secret.idtoken_jwks.id
  secret_data = jsonencode({
    keys = [
      {
        use = "sig",
        kty = "RSA",
        kid = "a2aa9739-d753-4a0d-87ee-61f101050277",
        alg = "RS256",
        n   = "zpjSl0ySsdk_YC4ZJYYV-cSznWkzndTo0lyvkYmeBkW60YHuHzXaviHqonY_DjFBdnZC0Vs_QTWmBlZvPzTp4Oni-eOetP-Ce3-B8jkGWpKFOjTLw7uwR3b3jm_mFNiz1dV_utWiweqx62Se0SyYaAXrgStU8-3P2Us7_kz5NnBVL1E7aEP40aB7nytLvPhXau-YhFmUfgykAcov0QrnNY0DH0eTcwL19UysvlKx6Uiu6mnbaFE1qx8X2m2xuLpErfiqj6wLCdCYMWdRTHiVsQMtTzSwuPuXfH7J06GTo3I1cEWN8Mb-RJxlosJA_q7hEd43yYisCO-8szX0lgCasw",
        e   = "AQAB",
        d   = "x3dfY_rna1UQTmFToBoMn6Edte47irhkra4VSNPwwaeTTvI-oN2TO51td7vo91_xD1nw-0c5FFGi4V2UfRcudBv9LD1rHt_O8EPUh7QtAUeT3_XXgjx1Xxpqu5goMZpkTyGZ-B6JzOY3L8lvWQ_Qeia1EXpvxC-oTOjJnKZeuwIPlcoNKMRU-mIYOnkRFfnUvrDm7N9UZEp3PfI3vhE9AquP1PEvz5KTUYkubsfmupqqR6FmMUm6ulGT7guhBw9A3vxIYbYGKvXLdBvn68mENrEYxXrwmu6ITMh_y208M5rC-hgEHIAIvMu1aVW6jNgyQTunsGST3UyrSbwjI0K9UQ",
        p   = "77fDvnfHRFEgyi7mh0c6fAdtMEMJ05W8NwTG_D-cSwfWipfTwJJrroWoRwEgdAg5AWGq-MNUzrubTVXoJdC2T4g1o-VRZkKKYoMvav3CvOIMzCBxBs9I_GAKr5NCSk7maksMqiCTMhmkoZ5RPuMYMY_YzxKNAbjBd9qFLfaVAqs",
        q   = "3KEmPA2XQkf7dvtpY1Xkp1IfMV_UBdmYk7J6dB5BYqzviQWdEFvWaSATJ_7qV1dw0JDZynOgipp8gvoL-RepfjtArhPz41wB3J2xmBYrBr1sJ-x5eqAvMkQk2bd5KTor44e79TRIkmkFYAIdUQ5JdVXPA13S8WUZfb_bAbwaCBk",
        dp  = "5uyy32AJkNFKchqeLsE6INMSp0RdSftbtfCfM86fZFQno5lA_qjOnO_avJPkTILDT4ZjqoKYxxJJOEXCffNCPPltGvbE5GrDXsUbP8k2-LgWNeoml7XFjIGEqcCFQoohQ1IK4DTDN6cmRh76C0e_Pbdh15D6TydJEIlsdGuu_kM",
        dq  = "aegFNYCEojFxeTzX6vIZL2RRSt8oJKK-Be__reu0EUzYMtr5-RdMhev6phFMph54LfXKRc9ZOg9MQ4cJ5klAeDKzKpyzTukkj6U20b2aa8LTvxpZec6YuTVSxxu2Ul71IGRQijTNvVIiXWLGddk409Ub6Q7JqkyQfvdwhpWnnUk",
        qi  = "P68-EwgcRy9ce_PZ75c909cU7dzCiaGcTX1psJiXmQAFBcG0msWfsyHGbllOZG27pKde78ORGJDYDNk1FqTwsogZyCP87EiBmOoqXWnMvKYfJ1DOx7x42LMAGwMD3bgQj9jgRACxFJG4n3NI6uFlFruyl_CLQzwW_rQFHshLK7Q"
      }
    ]
    }
  )
}
