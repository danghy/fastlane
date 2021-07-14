require 'spaceship'
require_relative 'module'

module Produce
  class DeveloperCenter
    SERVICE_ON = "on"
    SERVICE_OFF = "off"
    SERVICE_COMPLETE = "complete"
    SERVICE_UNLESS_OPEN = "unlessopen"
    SERVICE_UNTIL_FIRST_LAUNCH = "untilfirstauth"
    SERVICE_LEGACY = "legacy"
    SERVICE_CLOUDKIT = "cloudkit"

    ALLOWED_SERVICES = {
      access_wifi: [SERVICE_ON, SERVICE_OFF],
      app_group: [SERVICE_ON, SERVICE_OFF],
      apple_pay: [SERVICE_ON, SERVICE_OFF],
      associated_domains: [SERVICE_ON, SERVICE_OFF],
      auto_fill_credential: [SERVICE_ON, SERVICE_OFF],
      data_protection: [
        SERVICE_COMPLETE,
        SERVICE_UNLESS_OPEN,
        SERVICE_UNTIL_FIRST_LAUNCH
      ],
      game_center: [SERVICE_ON, SERVICE_OFF],
      health_kit: [SERVICE_ON, SERVICE_OFF],
      home_kit: [SERVICE_ON, SERVICE_OFF],
      hotspot: [SERVICE_ON, SERVICE_OFF],
      icloud: [SERVICE_LEGACY, SERVICE_CLOUDKIT],
      in_app_purchase: [SERVICE_ON, SERVICE_OFF],
      inter_app_audio: [SERVICE_ON, SERVICE_OFF],
      multipath: [SERVICE_ON, SERVICE_OFF],
      network_extension: [SERVICE_ON, SERVICE_OFF],
      nfc_tag_reading: [SERVICE_ON, SERVICE_OFF],
      personal_vpn: [SERVICE_ON, SERVICE_OFF],
      passbook: [SERVICE_ON, SERVICE_OFF],
      push_notification: [SERVICE_ON, SERVICE_OFF],
      siri_kit: [SERVICE_ON, SERVICE_OFF],
      vpn_configuration: [SERVICE_ON, SERVICE_OFF],
      wallet: [SERVICE_ON, SERVICE_OFF],
      wireless_accessory: [SERVICE_ON, SERVICE_OFF]
    }

    def run
      login
      create_new_app
    end

    def create_new_app
      ENV["CREATED_NEW_APP_ID"] = Time.now.to_i.to_s
      if app_exists?
        UI.success("[DevCenter] App '#{Produce.config[:app_identifier]}' already exists, nothing to do on the Dev Center")
        ENV["CREATED_NEW_APP_ID"] = nil
        # Nothing to do here
      else
        app_name = Produce.config[:app_name]
        UI.message("Creating new app '#{app_name}' on the Apple Dev Center")

        # app = Spaceship.app.create!(bundle_id: app_identifier,
        #                                  name: app_name,
        #                                  enable_services: enable_services,
        #                                  mac: platform == "osx")

        app = Spaceship::ConnectAPI::BundleId.create(name: app_name, identifier: app_identifier)

        if app.name != Produce.config[:app_name]
          UI.important("Your app name includes non-ASCII characters, which are not supported by the Apple Developer Portal.")
          UI.important("To fix this a unique (internal) name '#{app.name}' has been created for you. Your app's real name '#{Produce.config[:app_name]}'")
          UI.important("will still show up correctly on App Store Connect and the App Store.")
        end

        UI.message("Created app #{app.app_id}")

        UI.crash!("Something went wrong when creating the new app - it's not listed in the apps list") unless app_exists?

        ENV["CREATED_NEW_APP_ID"] = Time.now.to_i.to_s

        UI.success("Finished creating new app '#{app_name}' on the Dev Center")
      end

      return true
    end

    def enable_services
      app_service = Spaceship.app_service
      enabled_clean_options = {}

      # "enabled_features" was deprecated in favor of "enable_services"
      config_enabled_services = Produce.config[:enable_services] || Produce.config[:enabled_features]

      config_enabled_services.each do |k, v|
        if k.to_sym == :data_protection
          case v
          when SERVICE_COMPLETE
            enabled_clean_options[app_service.data_protection.complete.service_id] = app_service.data_protection.complete
          when SERVICE_UNLESS_OPEN
            enabled_clean_options[app_service.data_protection.unlessopen.service_id] = app_service.data_protection.unlessopen
          when SERVICE_UNTIL_FIRST_LAUNCH
            enabled_clean_options[app_service.data_protection.untilfirstauth.service_id] = app_service.data_protection.untilfirstauth
          end
        elsif k.to_sym == :icloud
          case v
          when SERVICE_LEGACY
            enabled_clean_options[app_service.cloud.on.service_id] = app_service.cloud.on
            enabled_clean_options[app_service.cloud_kit.xcode5_compatible.service_id] = app_service.cloud_kit.xcode5_compatible
          when SERVICE_CLOUDKIT
            enabled_clean_options[app_service.cloud.on.service_id] = app_service.cloud.on
            enabled_clean_options[app_service.cloud_kit.cloud_kit.service_id] = app_service.cloud_kit.cloud_kit
          end
        else
          if v == SERVICE_ON
            enabled_clean_options[app_service.send(k.to_s).on.service_id] = app_service.send(k.to_s).on
          else
            enabled_clean_options[app_service.send(k.to_s).off.service_id] = app_service.send(k.to_s).off
          end
        end
      end
      enabled_clean_options
    end

    def app_identifier
      Produce.config[:app_identifier].to_s
    end

    private

    def platform
      # This was added to support creation of multiple platforms
      # Produce::ItunesConnect can take an array of platforms to create for App Store Connect
      # but the Developer Center is now platform agnostic so we choose any platform here
      #
      # Platform won't be needed at all in the future when this is change over to use Spaceship::ConnectAPI
      (Produce.config[:platforms] || []).first || Produce.config[:platform]
    end

    def app_exists?
      Spaceship::ConnectAPI::BundleId.find(app_identifier) != nil
    end

    def login
      if (api_token = Spaceship::ConnectAPI::Token.from(hash: Produce.config[:api_key], filepath: Produce.config[:api_key_path]))
        UI.message("Creating authorization token for App Store Connect API")
        Spaceship::ConnectAPI.token = api_token
      elsif !Spaceship::ConnectAPI.token.nil?
        UI.message("Using existing authorization token for App Store Connect API")
      else
        Produce.config[:username] ||= CredentialsManager::AppfileConfig.try_fetch_value(:apple_id)

        # Username is now optional since addition of App Store Connect API Key
        # Force asking for username to prompt user if not already set
        Produce.config.fetch(:username, force_ask: true)

        UI.message("Login to App Store Connect (#{Produce.config[:username]})")
        # Spaceship::ConnectAPI.login(Produce.config[:username], use_portal: false, use_tunes: true, tunes_team_id: Produce.config[:team_id], team_name: Produce.config[:team_name])
        # Prompts select team if multiple teams and none specified
        Spaceship::ConnectAPI.login(Produce.config[:username], use_portal: true, use_tunes: false, portal_team_id: Produce.config[:team_id], team_name: Produce.config[:team_name])
        UI.message("Login successful")
      end
    end
  end
end
