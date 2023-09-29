resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group.name
  location = var.resource_group.location
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet.name
  address_space       = [var.vnet.address_space]
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  for_each = var.subnets

  name                 = each.value["name"]
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value["address_prefix"]]
}

# Create public IP
resource "azurerm_public_ip" "public_ip" {
  name                = var.public_ip.name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  allocation_method   = var.public_ip.allocation_method
  sku                 = var.public_ip.sku
}

# Create Application Gateway v2
resource "azurerm_application_gateway" "appgw" {
  name                = var.application_gateway.name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  sku {
    name     = var.application_gateway.sku.name
    tier     = var.application_gateway.sku.tier
    capacity = var.application_gateway.sku.capacity
  }
  gateway_ip_configuration {
    name      = var.application_gateway.gateway_ip_configuration.name
    subnet_id = azurerm_subnet.subnet[var.application_gateway.gateway_ip_configuration.subnet_name].id
  }
  frontend_port {
    name = var.application_gateway.frontend_port.name
    port = var.application_gateway.frontend_port.port
  }
  frontend_ip_configuration {
    name                 = var.application_gateway.frontend_ip_configuration.name
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
  backend_address_pool {
    name = var.application_gateway.backend_address_pool.name
  }
  backend_http_settings {
    name                  = var.application_gateway.backend_http_settings.name
    cookie_based_affinity = var.application_gateway.backend_http_settings.cookie_based_affinity
    path                  = var.application_gateway.backend_http_settings.path
    port                  = var.application_gateway.frontend_port.port
    protocol              = var.application_gateway.backend_http_settings.protocol
    request_timeout       = var.application_gateway.backend_http_settings.request_timeout
  }
  http_listener {
    name                           = var.application_gateway.http_listener.name
    frontend_ip_configuration_name = var.application_gateway.frontend_ip_configuration.name
    frontend_port_name             = var.application_gateway.frontend_port.name
    protocol                       = var.application_gateway.http_listener.protocol
  }
  request_routing_rule {
    name                       = var.application_gateway.request_routing_rule.name
    priority                   = var.application_gateway.request_routing_rule.priority
    rule_type                  = var.application_gateway.request_routing_rule.rule_type
    http_listener_name         = var.application_gateway.http_listener.name
    backend_address_pool_name  = var.application_gateway.backend_address_pool.name
    backend_http_settings_name = var.application_gateway.backend_http_settings.name
  }
  waf_configuration {
    enabled          = var.application_gateway.waf_configuration.enabled
    firewall_mode    = var.application_gateway.waf_configuration.firewall_mode
    rule_set_type    = var.application_gateway.waf_configuration.rule_set_type
    rule_set_version = var.application_gateway.waf_configuration.rule_set_version
    dynamic "disabled_rule_group" {
      for_each = var.application_gateway.waf_configuration.disabled_rule_groups
      content {
        rule_group_name = disabled_rule_group.value.rule_group_name
        rules           = disabled_rule_group.value.rules
      }
    }
    dynamic "exclusion" {
      for_each = var.application_gateway.waf_configuration.exclusions
      content {
        match_variable          = exclusion.value.match_variable
        selector                = exclusion.value.selector
        selector_match_operator = exclusion.value.selector_match_operator
      }
    }
  }
  firewall_policy_id                = try(azurerm_web_application_firewall_policy.waf_policy.id, null)
  force_firewall_policy_association = try(var.application_gateway.force_firewall_policy_association, true)
}

# Create WAF policy
resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = var.waf_policy.name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location

  dynamic "custom_rules" {
    for_each = var.waf_policy.custom_rules != null ? var.waf_policy.custom_rules : []

    content {
      enabled   = custom_rules.value.enabled
      name      = custom_rules.value.name
      priority  = custom_rules.value.priority
      rule_type = custom_rules.value.rule_type
      match_conditions {
        dynamic "match_variables" {
          for_each = custom_rules.value.match_conditions.match_variables != null ? custom_rules.value.match_conditions.match_variables : []
          content {
            variable_name = match_variables.value.variable_name
            selector      = match_variables.value.selector
          }
        }
        operator           = custom_rules.value.match_conditions.operator
        negation_condition = try(custom_rules.value.match_conditions.negation, null)
        match_values       = custom_rules.value.match_conditions.match_values
        transforms         = try(custom_rules.value.match_conditions.transforms, [])
      }
      action               = custom_rules.value.action
      rate_limit_duration  = try(custom_rules.value.rate_limit_duration, null)
      rate_limit_threshold = try(custom_rules.value.rate_limit_threshold, null)
      group_rate_limit_by  = try(custom_rules.value.group_rate_limit_by, null)
    }
  }
  policy_settings {
    enabled                     = try(var.waf_policy.policy_settings.enabled, null)
    mode                        = try(var.waf_policy.policy_settings.mode, null)
    file_upload_limit_in_mb     = try(var.waf_policy.policy_settings.file_upload_limit_in_mb, null)
    request_body_check          = try(var.waf_policy.policy_settings.request_body_check, null)
    max_request_body_size_in_kb = try(var.waf_policy.policy_settings.max_request_body_size_in_kb, null)
    log_scrubbing {
      enabled = try(var.waf_policy.policy_settings.log_scrubbing.enabled, null)
      rule {
        enabled                 = try(var.waf_policy.policy_settings.log_scrubbing.rule.enabled, null)
        match_variable          = try(var.waf_policy.policy_settings.log_scrubbing.rule.match_variable, null)
        selector                = try(var.waf_policy.policy_settings.log_scrubbing.rule.selector, null)
        selector_match_operator = try(var.waf_policy.policy_settings.log_scrubbing.rule.selector_match_operator, null)
      }
    }
    request_body_inspect_limit_in_kb = try(var.waf_policy.policy_settings.request_body_inspect_limit_in_kb, null)
  }
  managed_rules {
    dynamic "exclusion" {
      for_each = var.waf_policy.managed_rules.exclusion != null ? var.waf_policy.managed_rules.exclusion : []
      content {
        match_variable          = try(exclusion.value.match_variable, null)
        selector                = try(exclusion.value.selector, null)
        selector_match_operator = try(exclusion.value.selector_match_operator, null)
        dynamic "excluded_rule_set" {
          for_each = try(exclusion.value.excluded_rule_set, [])
          content {
            type    = try(excluded_rule_set.value.type, null)
            version = try(excluded_rule_set.value.version, null)
            dynamic "rule_group" {
              for_each = try(excluded_rule_set.value.rule_group, [])
              content {
                rule_group_name = try(rule_group.value.rule_group_name, null)
                excluded_rules  = try(rule_group.value.excluded_rules, [])
              }
            }
          }
        }
      }
    }
    dynamic "managed_rule_set" {
      for_each = try(var.waf_policy.managed_rules.managed_rule_set, [])
      content {
        type    = try(managed_rule_set.value.type, null)
        version = managed_rule_set.value.version

        dynamic "rule_group_override" {
          for_each = try(managed_rule_set.value.rule_group_override, [])
          content {
            rule_group_name = try(rule_group_override.value.rule_group_name, null)

            dynamic "rule" {
              for_each = try(rule_group_override.value.rule, [])
              content {
                id      = rule.value.id
                enabled = try(rule.value.enabled, null)
                action  = try(rule.value.action, null)
              }
            }
          }
        }
      }
    }
  }
  tags = try(var.waf_policy.tags, {})
}
