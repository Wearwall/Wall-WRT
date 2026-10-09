include $(TOPDIR)/rules.mk

PKG_NAME:=athena-led
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
GO_PKG:=athenaLed
GO_PKG_BUILD_PKG:=athenaLed
GO_PKG_LDFLAGS:=-s -w

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/athena-led
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=JDCloud Athena screen controller
  DEPENDS:=$(GO_ARCH_DEPENDS) +ca-bundle
endef

define Build/Prepare
	$(call Build/Prepare/Default)
	$(CP) $(CURDIR)/src/. $(PKG_BUILD_DIR)/
endef

define Package/athena-led/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(GO_PKG_BUILD_BIN_DIR)/athenaLed $(1)/usr/sbin/athena-led
endef

$(eval $(call GoBinPackage,athena-led))
$(eval $(call BuildPackage,athena-led))
