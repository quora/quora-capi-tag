___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Quora Conversions API",
  "brand": {
    "id": "github.com_quora",
    "displayName": "Quora"
  },
  "description": "Send server-side conversion events from your GA4 or Data client to the Quora Conversions API (CAPI).",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "accountId",
    "displayName": "Quora Ads Account ID",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "accessToken",
    "displayName": "Conversion API Access Token",
    "simpleValueType": true,
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ],
    "help": "Generate this in the Conversion API section of Quora Ads Manager. It is sent as a Bearer token from the server and is never exposed to the browser."
  },
  {
    "type": "RADIO",
    "name": "eventType",
    "displayName": "Event Name",
    "simpleValueType": true,
    "defaultValue": "inherit",
    "radioItems": [
      {
        "value": "inherit",
        "displayValue": "Inherit from the client event"
      },
      {
        "value": "standard",
        "displayValue": "Choose a standard Quora event",
        "subParams": [
          {
            "type": "SELECT",
            "name": "eventName",
            "displayName": "Quora Event",
            "macrosInSelect": false,
            "simpleValueType": true,
            "defaultValue": "Generic",
            "valueValidators": [
              {
                "type": "NON_EMPTY"
              }
            ],
            "selectItems": [
              { "value": "Generic", "displayValue": "Generic" },
              { "value": "ViewContent", "displayValue": "ViewContent" },
              { "value": "Search", "displayValue": "Search" },
              { "value": "AddToCart", "displayValue": "AddToCart" },
              { "value": "AddToWishlist", "displayValue": "AddToWishlist" },
              { "value": "InitiateCheckout", "displayValue": "InitiateCheckout" },
              { "value": "AddPaymentInfo", "displayValue": "AddPaymentInfo" },
              { "value": "Purchase", "displayValue": "Purchase" },
              { "value": "GenerateLead", "displayValue": "GenerateLead" },
              { "value": "CompleteRegistration", "displayValue": "CompleteRegistration" },
              { "value": "AppInstall", "displayValue": "AppInstall" }
            ]
          }
        ]
      }
    ]
  },
  {
    "type": "RADIO",
    "name": "adStorageConsent",
    "displayName": "Consent",
    "simpleValueType": true,
    "defaultValue": "optional",
    "radioItems": [
      {
        "value": "optional",
        "displayValue": "Always send"
      },
      {
        "value": "required",
        "displayValue": "Only send when ad_storage consent is granted"
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

const decodeUriComponent = require('decodeUriComponent');
const getAllEventData = require('getAllEventData');
const getCookieValues = require('getCookieValues');
const getRequestHeader = require('getRequestHeader');
const getTimestampMillis = require('getTimestampMillis');
const JSON = require('JSON');
const logToConsole = require('logToConsole');
const makeNumber = require('makeNumber');
const parseUrl = require('parseUrl');
const sendHttpRequest = require('sendHttpRequest');

const CONVERSION_URL = 'https://api.quora.com/ads/v0/conversion';
// The Quora pixel persists the click id in this first-party cookie on the
// advertiser's domain (90 days); this tag only reads it.
const QCLID_COOKIE = 'quora_qclid';

// Client event names -> Quora PixelCategory names. Anything not listed falls
// back to 'Generic', which is the catch-all category Quora's CAPI accepts.
const EVENT_NAME_MAP = {
  page_view: 'Generic',
  view_item: 'ViewContent',
  view_item_list: 'ViewContent',
  search: 'Search',
  add_to_cart: 'AddToCart',
  add_to_wishlist: 'AddToWishlist',
  begin_checkout: 'InitiateCheckout',
  add_payment_info: 'AddPaymentInfo',
  purchase: 'Purchase',
  generate_lead: 'GenerateLead',
  sign_up: 'CompleteRegistration',
  complete_registration: 'CompleteRegistration'
};

const eventData = getAllEventData();

if (!isConsentGiven()) return data.gtmOnSuccess();

const qclid = resolveQclid();

const conversion = { event_name: resolveEventName() };

const timestampMillis = eventData.timestamp || getTimestampMillis();
if (timestampMillis) conversion.timestamp = timestampMillis * 1000; // microseconds
if (eventData.event_id) conversion.event_id = eventData.event_id;
if (eventData.value !== undefined && eventData.value !== null && eventData.value !== '') {
  conversion.value = makeNumber(eventData.value);
}
if (qclid) conversion.click_id = qclid;

// device fields are all optional; include whatever the client provided.
const device = {};
if (eventData.page_referrer) device.referer = eventData.page_referrer;
if (eventData.user_agent) device.user_agent = eventData.user_agent;
if (eventData.language) device.language = eventData.language;
if (eventData.mobile_device_id) device.mobile_device_id = eventData.mobile_device_id;

// user is a required object in the CAPI payload but is sent empty (no user-data
// mapping in this version).
const requestBody = {
  account_id: makeNumber(data.accountId),
  conversion: conversion,
  user: {},
  device: device
};

if (!requestBody.account_id || !conversion.event_name) {
  logToConsole('Quora CAPI: missing account_id or event_name; not sending.');
  return data.gtmOnFailure();
}

sendHttpRequest(
  CONVERSION_URL,
  (statusCode) => {
    if (statusCode >= 200 && statusCode < 400) {
      data.gtmOnSuccess();
    } else {
      data.gtmOnFailure();
    }
  },
  {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer ' + data.accessToken
    }
  },
  JSON.stringify(requestBody)
);

function resolveEventName() {
  if (data.eventType === 'standard') return data.eventName;
  return EVENT_NAME_MAP[eventData.event_name] || 'Generic';
}

// qclid resolution order: the first-party cookie the Quora pixel persists
// (survives across pages), then the qclid query parameter on the landing URL
// (for a conversion that fires on the landing page itself), then whatever the
// client passed in the event data.
function resolveQclid() {
  const cookieQclid = getCookieValues(QCLID_COOKIE)[0];
  if (cookieQclid) return cookieQclid;

  const url = eventData.page_location || getRequestHeader('referer');
  if (url) {
    const parsed = parseUrl(url);
    if (parsed && parsed.searchParams.qclid) {
      return decodeUriComponent(parsed.searchParams.qclid);
    }
  }
  return eventData.qclid;
}

// Marketing-consent gate. When set to "required", only send if ad_storage is
// granted, via Consent Mode (consent_state) or the GA gcs signal (e.g. "G110").
function isConsentGiven() {
  if (data.adStorageConsent !== 'required') return true;
  // ad_storage may be a boolean or a Consent Mode string ("granted"/"denied").
  // Only an explicit grant passes -- a truthy "denied" must not.
  const adStorage = eventData.consent_state && eventData.consent_state.ad_storage;
  if (adStorage !== undefined && adStorage !== null) {
    return adStorage === true || adStorage === 'granted';
  }
  const gcs = eventData['x-ga-gcs'] || ''; // Consent Mode signal, e.g. "G111"
  return gcs[2] === '1';
}


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_request",
        "versionId": "1"
      },
      "param": [
        {
          "key": "headerWhitelist",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "headerName"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "referer"
                  }
                ]
              }
            ]
          }
        },
        {
          "key": "headersAllowed",
          "value": {
            "type": 8,
            "boolean": true
          }
        },
        {
          "key": "requestAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "headerAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "queryParameterAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_cookies",
        "versionId": "1"
      },
      "param": [
        {
          "key": "cookieAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "cookieNames",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "quora_qclid"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "eventDataAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "send_http",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://api.quora.com/ads/*"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Inherited client event maps to the Quora category and posts to CAPI
  code: |-
    const JSON = require('JSON');
    let capturedUrl;
    let capturedOptions;
    let capturedBody;

    mock('getCookieValues', () => []);
    mock('getTimestampMillis', () => 1600000000000);
    mock('getAllEventData', () => {
      return {
        event_name: 'purchase',
        value: 42,
        event_id: 'evt-1',
        page_location: 'https://shop.example.com/thanks?qclid=click-1|123|0'
      };
    });
    mock('sendHttpRequest', (url, callback, options, body) => {
      capturedUrl = url;
      capturedOptions = options;
      capturedBody = body;
      callback(200, {}, '');
    });

    runCode({
      accountId: '999',
      accessToken: 'tok',
      eventType: 'inherit',
      adStorageConsent: 'optional'
    });

    assertApi('sendHttpRequest').wasCalled();
    assertThat(capturedUrl).isEqualTo('https://api.quora.com/ads/v0/conversion');
    assertThat(capturedOptions.headers['Authorization']).isEqualTo('Bearer tok');

    const parsed = JSON.parse(capturedBody);
    assertThat(parsed.account_id).isEqualTo(999);
    assertThat(parsed.conversion.event_name).isEqualTo('Purchase');
    assertThat(parsed.conversion.value).isEqualTo(42);
    assertThat(parsed.conversion.click_id).isEqualTo('click-1|123|0');
- name: Unmapped inherited event falls back to Generic
  code: |-
    const JSON = require('JSON');
    let capturedBody;

    mock('getRequestHeader', () => undefined);
    mock('getCookieValues', () => []);
    mock('getTimestampMillis', () => 1600000000000);
    mock('getAllEventData', () => {
      return { event_name: 'my_custom_event' };
    });
    mock('sendHttpRequest', (url, callback, options, body) => {
      capturedBody = body;
      callback(200, {}, '');
    });

    runCode({
      accountId: '5',
      accessToken: 't',
      eventType: 'inherit',
      adStorageConsent: 'optional'
    });

    assertApi('sendHttpRequest').wasCalled();
    const parsed = JSON.parse(capturedBody);
    assertThat(parsed.conversion.event_name).isEqualTo('Generic');
- name: Standard mode uses the selected event name
  code: |-
    const JSON = require('JSON');
    let capturedBody;

    mock('getRequestHeader', () => undefined);
    mock('getCookieValues', () => []);
    mock('getTimestampMillis', () => 1600000000000);
    mock('getAllEventData', () => {
      return { event_name: 'purchase' };
    });
    mock('sendHttpRequest', (url, callback, options, body) => {
      capturedBody = body;
      callback(200, {}, '');
    });

    runCode({
      accountId: '5',
      accessToken: 't',
      eventType: 'standard',
      eventName: 'Search',
      adStorageConsent: 'optional'
    });

    const parsed = JSON.parse(capturedBody);
    assertThat(parsed.conversion.event_name).isEqualTo('Search');
- name: qclid is read from the first-party cookie when absent from the URL
  code: |-
    const JSON = require('JSON');
    let capturedBody;

    mock('getCookieValues', (name) => {
      return name === 'quora_qclid' ? ['cookie-qclid'] : [];
    });
    mock('getTimestampMillis', () => 1600000000000);
    mock('getAllEventData', () => {
      return {
        event_name: 'view_item',
        page_location: 'https://shop.example.com/item'
      };
    });
    mock('sendHttpRequest', (url, callback, options, body) => {
      capturedBody = body;
      callback(200, {}, '');
    });

    runCode({
      accountId: '5',
      accessToken: 't',
      eventType: 'inherit',
      adStorageConsent: 'optional'
    });

    const parsed = JSON.parse(capturedBody);
    assertThat(parsed.conversion.event_name).isEqualTo('ViewContent');
    assertThat(parsed.conversion.click_id).isEqualTo('cookie-qclid');
- name: Required consent that is denied blocks the send
  code: |-
    mock('getAllEventData', () => {
      return {
        event_name: 'purchase',
        consent_state: { ad_storage: 'denied' }
      };
    });
    mock('sendHttpRequest', () => {});

    runCode({
      accountId: '5',
      accessToken: 't',
      eventType: 'inherit',
      adStorageConsent: 'required'
    });

    assertApi('sendHttpRequest').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: Required consent that is granted allows the send
  code: |-
    mock('getCookieValues', () => []);
    mock('getRequestHeader', () => undefined);
    mock('getTimestampMillis', () => 1600000000000);
    mock('getAllEventData', () => {
      return {
        event_name: 'purchase',
        consent_state: { ad_storage: 'granted' }
      };
    });
    mock('sendHttpRequest', (url, callback, options, body) => {
      callback(200, {}, '');
    });

    runCode({
      accountId: '5',
      accessToken: 't',
      eventType: 'inherit',
      adStorageConsent: 'required'
    });

    assertApi('sendHttpRequest').wasCalled();
- name: Zero conversion value is preserved
  code: |-
    const JSON = require('JSON');
    let capturedBody;

    mock('getCookieValues', () => []);
    mock('getRequestHeader', () => undefined);
    mock('getTimestampMillis', () => 1600000000000);
    mock('getAllEventData', () => {
      return { event_name: 'purchase', value: 0 };
    });
    mock('sendHttpRequest', (url, callback, options, body) => {
      capturedBody = body;
      callback(200, {}, '');
    });

    runCode({
      accountId: '5',
      accessToken: 't',
      eventType: 'inherit',
      adStorageConsent: 'optional'
    });

    const parsed = JSON.parse(capturedBody);
    assertThat(parsed.conversion.value).isEqualTo(0);


___NOTES___

Quora Conversions API tag for server-side Google Tag Manager.
Sends conversion events to https://api.quora.com/ads/v0/conversion.
