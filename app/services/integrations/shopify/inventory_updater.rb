module Integrations
  module Shopify
    class InventoryUpdater
      def initialize(account, external_variant_id, new_quantity)
        @client = GraphqlClient.new(account)
        @variant_gid = Helpers.gid("ProductVariant", external_variant_id)
        @new_quantity = new_quantity
        @account = account
      end

      def call
        inventory_item_gid = get_inventory_item_gid
        location_gid = get_location_gid

        raise "No location found" unless location_gid

        current_quantity = get_current_quantity(inventory_item_gid, location_gid)
        delta = @new_quantity - current_quantity

        return if delta.zero?

        data = @client.call(mutation, variables(inventory_item_gid, location_gid, delta))

        errors = data.dig("inventoryAdjustQuantities", "userErrors")
        raise "Shopify Error: #{errors}" if errors.present?

        log_success(current_quantity, delta)
      rescue => e
        log_failure(e.message)
        raise e
      end

      private

      def mutation
        <<~GRAPHQL
        mutation($input: InventoryAdjustQuantitiesInput!) {
          inventoryAdjustQuantities(input: $input) {
            userErrors { field message }
          }
        }
        GRAPHQL
      end

      def variables(item_gid, location_gid, delta)
        {
          input: {
            reason: "correction",
            name: "available",
            changes: [ {
              inventoryItemId: item_gid,
              locationId: location_gid,
              delta: delta
            } ]
          }
        }
      end

      def log_success(current, delta)
        SyncLoggerService.log(
          organization: @account.organization,
          resource: @account,
          action: "shopify_inventory_update",
          status: "success",
          message: "Updated #{current} → #{@new_quantity} (delta #{delta})"
        )
      end

      def log_failure(msg)
        SyncLoggerService.log(
          organization: @account.organization,
          resource: @account,
          action: "shopify_inventory_update",
          status: "failed",
          message: msg
        )
      end

      # helper queries (same logic as before, just moved)
      def get_inventory_item_gid
        data = @client.call(<<~GRAPHQL, { id: @variant_gid })
        query($id: ID!) {
          productVariant(id: $id) {
            inventoryItem { id }
          }
        }
        GRAPHQL

        data.dig("productVariant", "inventoryItem", "id")
      end

      def get_location_gid
        data = @client.call(<<~GRAPHQL, { inventoryItemId: get_inventory_item_gid })
        query($inventoryItemId: ID!) {
          inventoryItem(id: $inventoryItemId) {
            inventoryLevels(first: 10) {
              nodes { location { id } }
            }
          }
        }
        GRAPHQL

        data.dig("inventoryItem", "inventoryLevels", "nodes")&.first&.dig("location", "id")
      end

      def get_current_quantity(item_gid, location_gid)
        data = @client.call(<<~GRAPHQL, { inventoryItemId: item_gid })
        query($inventoryItemId: ID!) {
          inventoryItem(id: $inventoryItemId) {
            inventoryLevels(first: 10) {
              nodes {
                location { id }
                quantities(names: ["available"]) {
                  name quantity
                }
              }
            }
          }
        }
        GRAPHQL

        levels = data.dig("inventoryItem", "inventoryLevels", "nodes") || []
        level = levels.find { |l| l.dig("location", "id") == location_gid }

        level&.dig("quantities")&.find { |q| q["name"] == "available" }&.dig("quantity") || 0
      end
    end
  end
end
