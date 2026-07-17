# Quora Conversions API — Server-Side GTM Template

An official [Quora](https://www.quora.com) server-side Google Tag Manager (sGTM)
tag template. It reads an event from your GA4 or Data client, maps it to Quora's
Conversions API (CAPI) request, and sends it server-to-server to
`https://api.quora.com/ads/v0/conversion`.

## Configuration

| Field | Required | Description |
| --- | --- | --- |
| Quora Ads Account ID | yes | Your Quora Ads account ID. |
| Conversion API Access Token | yes | Generated in the Conversion API section of Quora Ads Manager. Sent as a Bearer token from the server; never exposed to the browser. |
| Event Name | yes | `Inherit from the client event` (auto-map the incoming event) or `Choose a standard Quora event`. |
| Consent | no | `Always send`, or only send when `ad_storage` marketing consent is granted. |

`event_id`, `value`, `timestamp`, and device fields (referer, user agent,
language, mobile device id) are read automatically from the client event when
present. `user` data is not mapped in this version.

## Quora click ID (qclid)

Attribution on Quora's CAPI is keyed on the Quora click ID (`qclid`). The Quora
**pixel** captures the `qclid` from the landing-page URL and persists it in a
first-party `quora_qclid` cookie on your domain (90 days). This tag only reads
it, in order: the `quora_qclid` cookie, then the `qclid` URL parameter (for a
conversion that fires on the landing page itself), then the client event data.

The Quora pixel must be installed for cross-page attribution: a conversion that
fires on a later page (e.g. a checkout) relies on the `quora_qclid` cookie the
pixel set on the landing page. Conversions sent without a qclid are accepted by
the API but cannot be attributed to an ad click.

## Valid event names

`Generic`, `ViewContent`, `AppInstall`, `Purchase`, `GenerateLead`,
`CompleteRegistration`, `AddPaymentInfo`, `AddToCart`, `AddToWishlist`,
`InitiateCheckout`, `Search`. Inherited events that do not map to one of these
fall back to `Generic`.

## License

Licensed under the Apache License 2.0 (see `LICENSE`).
