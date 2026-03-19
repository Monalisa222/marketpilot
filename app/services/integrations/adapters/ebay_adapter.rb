module Integrations
  module Adapters
    class EbayAdapter < BaseAdapter
      def initialize(account)
        super
        @client = Integrations::Ebay::EbayClient.new(account)
      end

      # --------------------------------
      # FETCH PRODUCTS
      # --------------------------------
      def fetch_products
        Integrations::Ebay::ProductFetcher
          .new(@account)
          .call
      rescue => e
        Rails.logger.error("EbayAdapter fetch_products error: #{e.message}")
        []
      end

      # --------------------------------
      # FETCH ORDERS
      # --------------------------------
      def fetch_orders
        Integrations::Ebay::OrderFetcher
          .new(@account)
          .call
      rescue => e
        Rails.logger.error("EbayAdapter fetch_orders error: #{e.message}")
        []
      end

      # --------------------------------
      # CREATE PRODUCT
      # --------------------------------
      def create_product(product)
        results = []

        product.variants.each do |variant|
          if variant.sku.blank?
            results << { success: false, error: "Missing SKU", sku: nil }
            next
          end

          existing_offer = get_offer_by_sku(variant.sku)
          if existing_offer.present?
            results << { success: true, message: "Duplicate skipped", sku: variant.sku }
            next
          end

          create_inventory_item(variant)

          offer_id = create_offer(variant)
          if offer_id.blank?
            results << { success: false, error: "Offer creation failed", sku: variant.sku }
            next
          end

          publish_offer(offer_id)
          create_listing(variant, offer_id)

          results << { success: true, message: "Created", sku: variant.sku }
        end

        results
      end

      # --------------------------------
      # UPDATE INVENTORY
      # --------------------------------
      def update_inventory(listing, quantity)
        return { success: false, error: "Missing quantity" } if quantity.nil?

        sku = listing.variant&.sku
        return { success: false, error: "Missing SKU" } if sku.blank?

        @client.put("/sell/inventory/v1/inventory_item/#{sku}", {
          availability: {
            shipToLocationAvailability: {
              quantity: quantity
            }
          }
        })

        { success: true, message: "Inventory updated", sku: sku }
      rescue => e
        { success: false, error: e.message }
      end

      # --------------------------------
      # UPDATE PRICE
      # --------------------------------
      def update_price(listing, price)
        return { success: false, error: "Missing price" } if price.blank?

        offer_id = listing.external_id
        return { success: false, error: "Missing offer_id" } if offer_id.blank?

        @client.put("/sell/inventory/v1/offer/#{offer_id}", {
          pricingSummary: {
            price: {
              value: price.to_s,
              currency: "USD"
            }
          }
        })

        { success: true, message: "Price updated", sku: listing.variant&.sku }
      rescue => e
        { success: false, error: e.message }
      end

      private

      def create_inventory_item(variant)
        return if variant.quantity.nil?

        @client.put("/sell/inventory/v1/inventory_item/#{variant.sku}", {
          product: {
            title: variant.product.title
          },
          availability: {
            shipToLocationAvailability: {
              quantity: variant.quantity
            }
          }
        })
      end

      def create_offer(variant)
        return nil if variant.price.blank?

        response = @client.post("/sell/inventory/v1/offer", {
          sku: variant.sku,
          marketplaceId: "EBAY_US",
          format: "FIXED_PRICE",
          availableQuantity: variant.quantity || 0,
          pricingSummary: {
            price: {
              value: variant.price.to_s,
              currency: "USD"
            }
          }
        })

        response["offerId"]
      end

      def publish_offer(offer_id)
        @client.post("/sell/inventory/v1/offer/#{offer_id}/publish")
      end

      def get_offer_by_sku(sku)
        return {} if sku.blank?

        data = @client.get("/sell/inventory/v1/offer?sku=#{sku}")
        data["offers"]&.first || {}
      end

      def fetch_price(sku)
        offer = get_offer_by_sku(sku)
        price = offer.dig("pricingSummary", "price", "value")
        price.present? ? price.to_f : 0.0
      rescue
        0.0
      end

      def create_listing(variant, offer_id)
        Listing.find_or_initialize_by(
          marketplace_account_id: @account.id,
          external_id: offer_id
        ).update!(
          variant: variant,
          price: variant.price || 0,
          quantity: variant.quantity || 0
        )
      end
    end
  end
end
