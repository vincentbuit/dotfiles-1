//mostly url-bar
user_pref("browser.uiCustomization.state", '
    {
      "placements": {
        "widget-overflow-fixed-list": [],
        "PersonalToolbar": [ "personal-bookmarks" ],
        "nav-bar": [ "urlbar-container", "downloads-button" ],
        "TabsToolbar": [ "tabbrowser-tabs", "alltabs-button" ],
        "toolbar-menubar": [ "menubar-items" ]
      },
      "seen": [
        "ublock0_raymondhill_net-browser-action",
        "developer-button"
      ],
      "dirtyAreaCache": [
        "PersonalToolbar",
        "nav-bar",
        "TabsToolbar",
        "toolbar-menubar"
      ],
      "currentVersion": 12,
      "newElementCount": 0
    }
');
user_pref("browser.pageActions.persistedActions", '
    {
      "version": 1,
      "ids": [
        "bookmark",
        "bookmarkSeparator",
        "copyURL",
        "emailLink",
        "sendToDevice",
        "screenshots"
      ],
      "idsInUrlbar": []
    }
');
user_pref("identity.fxaccounts.enabled", false);
user_pref("browser.ctrlTab.previews", true);
user_pref("widget.allow-client-side-decoration", true);
user_pref("browser.tabs.warnOnClose", false);
user_pref("lightweightThemes.selectedThemeID",
    "firefox-compact-dark@mozilla.org");
user_pref("reader.parse-on-load.enabled", false);
user_pref("extensions.pocket.enabled", false);
user_pref("full-screen-api.warning.timeout", 0);
user_pref("browser.in-content.dark-mode", true);
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
