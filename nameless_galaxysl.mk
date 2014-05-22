# Get the prebuilt list of APNs
$(call inherit-product, vendor/nameless/config/apns.mk)

# Release name
PRODUCT_RELEASE_NAME := SGSL

# Inherit from the common Open Source product configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

$(call inherit-product, vendor/nameless/config/common.mk)

# Inherit device configuration
$(call inherit-product, device/samsung/galaxysl/full_galaxysl.mk)

## Device identifier. This must come after all inclusions
PRODUCT_DEVICE := galaxysl
PRODUCT_NAME := nameless_galaxysl
PRODUCT_BRAND := Samsung
PRODUCT_MODEL := GT-I9003
