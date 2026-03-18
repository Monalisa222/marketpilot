module Integrations
  module Shopify
    class ProductCreator < BaseService
      def initialize(product, account)
        super(account: account, resource: product)

        @product = product
        @account = account
        @client = GraphqlClient.new(account)
      end

      def call
        if already_pushed?
          log_success("shopify_product_skip", "Product already pushed")
          return
        end

        product = create_product
        create_variants(product["id"])

        log_success("shopify_product_create", "Created #{product['id']}")

        product
      rescue => e
        log_failure("shopify_product_create", e.message)
        raise e
      end

      private

      # --------------------------------
      # IDEMPOTENCY (USING LISTINGS)
      # --------------------------------
      def already_pushed?
        @product.variants.all? do |variant|
          variant.listings.exists?(marketplace_account_id: @account.id)
        end
      end

      # --------------------------------
      # STEP 1: CREATE PRODUCT
      # --------------------------------
      def create_product
        data = @client.call(product_mutation, product_variables)

        errors = data.dig("productCreate", "userErrors")
        raise "Product Create Error: #{errors}" if errors.present?

        data.dig("productCreate", "product")
      end

      def product_mutation
        <<~GRAPHQL
        mutation($input: ProductInput!) {
          productCreate(input: $input) {
            product {
              id
              title
            }
            userErrors {
              field
              message
            }
          }
        }
        GRAPHQL
      end

      def product_variables
        {
          input: {
            title: @product.title
          }
        }
      end

      # --------------------------------
      # STEP 2: HANDLE VARIANTS
      # --------------------------------
      def create_variants(product_gid)
        return if @product.variants.blank?

        # 1. Get default Shopify variant
        default_variant_gid = fetch_default_variant_id(product_gid)

        # 2. Update default variant with first local variant
        first_variant = @product.variants.first
        update_default_variant(product_gid, default_variant_gid, first_variant)

        # 3. Create remaining variants
        remaining_variants = @product.variants.drop(1)
        return if remaining_variants.blank?

        data = @client.call(
          variant_mutation,
          variant_variables(product_gid, remaining_variants)
        )

        errors = data.dig("productVariantsBulkCreate", "userErrors")
        raise "Variant Create Error: #{errors}" if errors.present?

        create_listings_for_new_variants(data, remaining_variants)
      end

      # --------------------------------
      # FETCH DEFAULT VARIANT
      # --------------------------------
      def fetch_default_variant_id(product_gid)
        data = @client.call(<<~GRAPHQL, { id: product_gid })
        query($id: ID!) {
          product(id: $id) {
            variants(first: 1) {
              nodes {
                id
              }
            }
          }
        }
        GRAPHQL

        data.dig("product", "variants", "nodes", 0, "id")
      end

      # --------------------------------
      # UPDATE DEFAULT VARIANT
      # --------------------------------
      def update_default_variant(product_gid, variant_gid, variant)
        query = <<~GRAPHQL
          mutation($productId: ID!, $variants: [ProductVariantsBulkInput!]!) {
            productVariantsBulkUpdate(productId: $productId, variants: $variants) {
              userErrors {
                field
                message
              }
            }
          }
        GRAPHQL

        variables = {
          productId: product_gid,
          variants: [
            {
              id: variant_gid,
              price: variant.price.to_s,
              inventoryItem: {
                sku: variant.sku || "SKU-#{variant.id}"
              }
            }
          ]
        }

        data = @client.call(query, variables)

        errors = data.dig("productVariantsBulkUpdate", "userErrors")
        raise "Default Variant Update Error: #{errors}" if errors.present?

        create_listing(variant, variant_gid)
      end

      # --------------------------------
      # CREATE REMAINING VARIANTS
      # --------------------------------
      def variant_mutation
        <<~GRAPHQL
        mutation($productId: ID!, $variants: [ProductVariantsBulkInput!]!) {
          productVariantsBulkCreate(productId: $productId, variants: $variants) {
            productVariants {
              id
              price
            }
            userErrors {
              field
              message
            }
          }
        }
        GRAPHQL
      end

      def variant_variables(product_gid, variants)
        {
          productId: product_gid,
          variants: variants.map do |variant|
            {
              price: variant.price.to_s,
              inventoryItem: {
                sku: variant.sku || "SKU-#{variant.id}"
              },
              inventoryQuantities: [
                {
                  availableQuantity: variant.quantity || 0,
                  locationId: default_location_gid
                }
              ]
            }
          end
        }
      end

      # --------------------------------
      # LISTINGS (MAPPING LAYER)
      # --------------------------------
      def create_listing(variant, gid)
        Listing.create!(
          marketplace_account_id: @account.id,
          variant: variant,
          external_id: extract_id(gid)
        )
      end

      def create_listings_for_new_variants(data, variants)
        shopify_variants = data.dig("productVariantsBulkCreate", "productVariants")

        variants.each_with_index do |variant, index|
          gid = shopify_variants[index]["id"]
          create_listing(variant, gid)
        end
      end

      def extract_id(gid)
        gid.split("/").last
      end

      # --------------------------------
      # LOCATION
      # --------------------------------
      def default_location_gid
        @default_location_gid ||= fetch_location_gid
      end

      def fetch_location_gid
        data = @client.call(<<~GRAPHQL)
        {
          locations(first: 1) {
            nodes { id }
          }
        }
        GRAPHQL

        data.dig("locations", "nodes", 0, "id")
      end
    end
  end
end
