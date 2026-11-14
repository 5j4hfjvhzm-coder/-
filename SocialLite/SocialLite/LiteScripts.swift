import Foundation

/// 페이지에 넣는 CSS/JS. 각 사이트의 화면 구조가 바뀌면 일부 선택자가 안 맞을 수 있어요(최대한 맞추는 방식).
@MainActor
enum LiteScripts {

    static func css(for p: Platform, settings s: AppSettings) -> String {
        var rules: [String] = []
        func hide(_ selectors: [String]) {
            rules.append(selectors.joined(separator: ",\n") + " { display: none !important; }")
        }

        if s.hideAppBanners {
            hide([
                "a[href^=\"https://apps.apple.com\"]",
                "a[href^=\"https://itunes.apple.com\"]",
                "a[href^=\"itms-apps:\"]",
            ])
        }

        switch p {
        case .youtube:
            if s.hideShorts {
                hide([
                    "ytm-reel-shelf-renderer",
                    "ytm-shorts-lockup-view-model",
                    "ytm-shorts-lockup-view-model-v2",
                    "ytm-reel-item-renderer",
                    "ytm-rich-section-renderer:has(ytm-shorts-lockup-view-model)",
                    "ytm-rich-section-renderer:has(ytm-shorts-lockup-view-model-v2)",
                    "ytm-rich-section-renderer:has(ytm-reel-shelf-renderer)",
                    "grid-shelf-view-model:has(ytm-shorts-lockup-view-model)",
                    "ytm-item-section-renderer:has(ytm-reel-shelf-renderer)",
                    "ytm-video-with-context-renderer:has(a[href^=\"/shorts/\"])",
                    "ytm-compact-video-renderer:has(a[href^=\"/shorts/\"])",
                    "ytm-pivot-bar-item-renderer:has(.pivot-shorts)",
                ])
            }
            if s.hideAds {
                hide([
                    "ad-slot-renderer",
                    "ytm-ad-slot-renderer",
                    "ytm-promoted-video-renderer",
                    "ytm-promoted-sparkles-web-renderer",
                    "ytm-promoted-sparkles-text-search-renderer",
                    "ytm-companion-ad-renderer",
                    "ytm-rich-item-renderer:has(ad-slot-renderer)",
                    "ytm-item-section-renderer:has(ad-slot-renderer)",
                    "ytm-statement-banner-renderer",
                ])
            }
            if s.hideAppBanners {
                hide(["ytm-mealbar-promo-renderer", ".mealbar-promo-renderer"])
            }
        case .instagram:
            if s.hideReelsTab {
                hide(["a[href=\"/reels/\"]", "a[href^=\"/reels/\"]"])
            }
        case .tiktok:
            if s.hideAppBanners {
                hide([
                    "[data-e2e*=\"open-app\"]",
                    "[class*=\"OpenAppButton\"]",
                    "[class*=\"DivOpenApp\"]",
                    "[class*=\"BannerOpenApp\"]",
                ])
            }
        }

        // 루트(html)에 거는 filter는 고정 위치 요소를 깨뜨리지 않아요.
        if s.grayscale {
            rules.append("html { filter: grayscale(1) !important; }")
        }
        return rules.joined(separator: "\n")
    }

    static func hidesSponsored(_ p: Platform, settings s: AppSettings) -> Bool {
        p == .instagram && s.hideSponsored
    }

    /// 페이지가 열릴 때(문서 시작) 한 번 들어가는 스크립트.
    static func bootstrap(css: String, sponsored: Bool) -> String {
        """
        (function () {
          if (window.__socialLite) { window.__socialLite.update(\(js(css)), \(sponsored)); return; }
          var sl = window.__socialLite = { css: \(js(css)), sponsored: \(sponsored) };
          var words = ['Sponsored', '광고', 'Gesponsert', 'Sponsorisé', 'Patrocinado', 'Sponsorizzato', '広告', 'スポンサー'];
          function ensureStyle() {
            var s = document.getElementById('sociallite-style');
            if (!s) {
              s = document.createElement('style');
              s.id = 'sociallite-style';
              (document.head || document.documentElement).appendChild(s);
            }
            if (s.textContent !== sl.css) s.textContent = sl.css;
          }
          function hideSponsored() {
            if (!sl.sponsored) return;
            document.querySelectorAll('article:not([data-sl-ad])').forEach(function (a) {
              var els = a.querySelectorAll('span, a, div');
              for (var i = 0; i < els.length; i++) {
                var el = els[i];
                if (el.childElementCount === 0 && words.indexOf((el.textContent || '').trim()) !== -1) {
                  a.setAttribute('data-sl-ad', '');
                  a.style.setProperty('display', 'none', 'important');
                  break;
                }
              }
            });
          }
          var pending = false;
          function tick() { pending = false; ensureStyle(); hideSponsored(); }
          new MutationObserver(function () {
            if (!pending) { pending = true; setTimeout(tick, 250); }
          }).observe(document.documentElement, { childList: true, subtree: true });
          sl.update = function (css, sponsored) {
            sl.css = css; sl.sponsored = sponsored;
            if (!sponsored) {
              document.querySelectorAll('[data-sl-ad]').forEach(function (a) {
                a.removeAttribute('data-sl-ad'); a.style.removeProperty('display');
              });
            }
            tick();
          };
          tick();
        })();
        """
    }

    /// 이미 열린 페이지에 바뀐 설정을 바로 적용.
    static func update(css: String, sponsored: Bool) -> String {
        "window.__socialLite && window.__socialLite.update(\(js(css)), \(sponsored));"
    }

    /// Swift 문자열을 안전한 JS 문자열 리터럴로.
    static func js(_ s: String) -> String {
        guard let data = try? JSONEncoder().encode(s), let out = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return out
    }
}
