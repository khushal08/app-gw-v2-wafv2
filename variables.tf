variable "resource_group" {
  type = map(string)
  default = {
    "name"     = "demo-appgw-rg"
    "location" = "eastus"
  }
}

variable "vnet" {
  type = map(string)
  default = {
    "name"          = "demo-appgw-vnet"
    "address_space" = "192.168.0.0/16"
  }
}

variable "subnets" {
  type = map(map(string))
  default = {
    "appgw" = {
      "name"           = "ApplicationGateway"
      "address_prefix" = "192.168.0.0/24"
    },
    "backend" = {
      "name"           = "backend"
      "address_prefix" = "192.168.1.0/24"
    }
  }
}

variable "public_ip" {
  type = map(string)
  default = {
    "name"              = "demo-appgw-pip"
    "allocation_method" = "Static"
    "sku"               = "Standard"
  }
}

variable "application_gateway" {
  type = object({
    name = string
    sku = object({
      name     = string
      tier     = string
      capacity = number
    })
    gateway_ip_configuration = object({
      name        = string
      subnet_name = string
    })
    frontend_port = object({
      name = string
      port = number
    })
    frontend_ip_configuration = object({
      name = string
    })
    backend_address_pool = object({
      name = string
    })
    backend_http_settings = object({
      name                  = string
      cookie_based_affinity = string
      path                  = string
      port                  = number
      protocol              = string
      request_timeout       = number
    })
    http_listener = object({
      name                           = string
      frontend_ip_configuration_name = string
      frontend_port_name             = string
      protocol                       = string
    })
    request_routing_rule = object({
      name                       = string
      priority                   = number
      rule_type                  = string
      http_listener_name         = string
      backend_address_pool_name  = string
      backend_http_settings_name = string
    })
    waf_configuration = object({
      enabled          = bool
      firewall_mode    = string
      rule_set_type    = optional(string)
      rule_set_version = string
      disabled_rule_groups = optional(list(object({
        rule_group_name = string
        rules           = optional(list(string))
      })))
      file_upload_limit_in_mb = optional(number)
      request_body_check      = optional(bool)
      max_request_body_size   = optional(number)
      exclusions = optional(list(object({
        match_variable          = string
        selector_match_operator = optional(string)
        selector                = optional(string)
      })))
    })
    firewall_policy_id                = optional(string)
    force_firewall_policy_association = optional(bool)
  })
  default = {
    "name" = "demo-appgw"
    "sku" = {
      "name"     = "WAF_v2"
      "tier"     = "WAF_v2"
      "capacity" = 2
    }
    "gateway_ip_configuration" = {
      "name"        = "appGatewayIpConfig"
      "subnet_name" = "appgw"
    }
    "frontend_port" = {
      "name" = "fe_port_http"
      "port" = 80
    }
    "frontend_ip_configuration" = {
      "name" = "appGatewayFrontendIP"
    }
    "backend_address_pool" = {
      "name" = "appGatewayBackendPool"
    }
    "backend_http_settings" = {
      "name"                  = "appGatewayBackendHttpSettings"
      "cookie_based_affinity" = "Disabled"
      "path"                  = "/"
      "port"                  = 80
      "protocol"              = "Http"
      "request_timeout"       = 60
    }
    "http_listener" = {
      "name"                           = "appGatewayHttpListener"
      "frontend_ip_configuration_name" = "appGatewayFrontendIP"
      "frontend_port_name"             = "port_80"
      "protocol"                       = "Http"
    }
    "request_routing_rule" = {
      "name"                       = "appGatewayRule"
      "priority"                   = 1
      "rule_type"                  = "Basic"
      "http_listener_name"         = "appGatewayHttpListener"
      "backend_address_pool_name"  = "appGatewayBackendPool"
      "backend_http_settings_name" = "appGatewayBackendHttpSettings"
    }
    waf_configuration = {
      enabled               = true
      firewall_mode         = "Detection"
      rule_set_type         = "OWASP"
      rule_set_version      = "3.1"
      request_body_check    = true
      max_request_body_size = 128
      disabled_rule_groups = [{
        rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
        rules           = ["920130"]
      }]
      exclusions = [{
        match_variable          = "RequestHeaderNames"
        selector_match_operator = "Contains"
        selector                = "User-Agent"
      }]
    }
    force_firewall_policy_association = true
  }
}

variable "waf_policy" {
  type = object({
    name = string
    custom_rules = list(object({
      enabled   = optional(bool)
      name      = string
      priority  = number
      rule_type = string
      match_conditions = object({
        match_variables = list(object({
          variable_name = string
          selector      = optional(string)
        }))
        operator           = string
        match_values       = list(string)
        negation_condition = optional(bool)
        transforms         = optional(list(string))
      })
      action               = string
      rate_limit_duration  = optional(string)
      rate_limit_threshold = optional(number)
      group_rate_limit_by  = optional(string)
    }))
    policy_settings = optional(object({
      enabled                     = optional(bool)
      mode                        = optional(string)
      file_upload_limit_in_mb     = optional(number)
      request_body_check          = optional(bool)
      max_request_body_size_in_kb = optional(number)
      log_scrubbing = optional(object({
        enabled = optional(bool)
        rule = optional(object({
          enabled                 = optional(bool)
          match_variable          = optional(string)
          selector                = optional(string)
          selector_match_operator = optional(string)
        }))
      }))
      request_body_inspect_limit_in_kb = optional(number)
    }))
    managed_rules = object({
      exclusion = optional(list(object({
        match_variable          = string
        selector                = string
        selector_match_operator = string
        excluded_rule_set = optional(list(object({
          type    = optional(string)
          version = optional(string)
          rule_group = optional(list(object({
            rule_group_name = string
            excluded_rules  = optional(list(string))
          })))
        })))
      })))
      managed_rule_set = optional(list(object({
        type    = string
        version = string
        rule_group_overrides = optional(list(object({
          rule_group_name = string
          rule = optional(list(object({
            id      = string
            enabled = optional(bool)
            action  = optional(string)
          })))
        })))
      })))
    })
    tags = optional(map(string))
  })
  default = {
    "name" = "demo-appgw-waf-policy"
    "custom_rules" = [{
      "enabled"   = true
      "name"      = "demo-appgw-waf-policy-rule"
      "priority"  = 1
      "rule_type" = "MatchRule"

      "match_conditions" = {
        "match_variables" = [{
          "variable_name" = "RemoteAddr"
        }]
        "operator"           = "IPMatch"
        "negation_condition" = false
        "match_values"       = ["192.168.1.0/24", "10.0.0.0/24"]
      }
      "action" = "Block"
      },
      {
        "enabled"   = true
        "name"      = "demo-appgw-waf-policy-rule2"
        "priority"  = 2
        "rule_type" = "MatchRule"

        "match_conditions" = {
          "match_variables" = [{
            "variable_name" = "RemoteAddr"
            },
            {
              "variable_name" = "RequestHeaders"
              "selector"      = "UserAgent"
          }]
          "operator"           = "IPMatch"
          "negation_condition" = false
          "match_values"       = ["192.168.1.0/24"]
        }
        action = "Block"
    }]
    "policy_settings" = {
      "enabled"                     = true
      "mode"                        = "Detection"
      "file_upload_limit_in_mb"     = 100
      "request_body_check"          = true
      "max_request_body_size_in_kb" = 128
      "log_scrubbing" = {
        "enabled" = true
        "rule" = {
          "enabled"        = true
          "match_variable" = "RequestHeaderNames"
          # "selector"                = "User-Agent"
          "selector_match_operator" = "EqualsAny"
        }
      }
      "request_body_inspect_limit_in_kb" = 128
    }
    managed_rules = {
      exclusion = [{
        match_variable          = "RequestHeaderNames"
        selector                = "x-company-secret-header"
        selector_match_operator = "Equals"
        excluded_rule_set = [{
          type    = "OWASP"
          version = "3.2"
          rule_group = [{
            rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
            excluded_rules  = ["920100"]
          }]
        }]
      }]
      managed_rule_set = [{
        type    = "OWASP"
        version = "3.2"
        rule_group_overrides = [{
          rule_group_name = "REQUEST-920-PROTOCOL-ENFORCEMENT"
          rule = [{
            id      = "920120"
            enabled = true
            action  = "Block"
            },
            {
              id      = "920171"
              enabled = true
              action  = "Block"
          }]
        }]
      }]
    }
    tags = {
      "name" = "demo-app-gw-wafv2"
      "env"  = "dev"
    }
  }
}
