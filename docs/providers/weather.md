# Weather

[Documentation index](../index.md#providers)

A `weather` item shows current temperature and a condition icon using
[Open-Meteo](https://open-meteo.com/):

```json
{
  "id": "weather",
  "type": "weather",
  "weather": {
    "latitude": 51.5074,
    "longitude": -0.1278,
    "temperatureUnit": "celsius",
    "windSpeedUnit": "kmh",
    "pollInterval": 900
  }
}
```

Both coordinates are required. Latitude must be between -90 and 90, and longitude
between -180 and 180. There is no automatic location lookup or location permission.

The default label is rounded temperature, such as `18°C`. Temperature units are
`celsius` and `fahrenheit`; wind units are `kmh`, `mph`, `ms`, and `kn`. Defaults are
Celsius and km/h. Items with identical coordinates share a request across displays,
even when they use different units. Unit conversion happens before rounding.

Weather is fetched immediately, then `pollInterval` seconds after each request
finishes. The default is 900 seconds, with an accepted range of 60 to 86400.
The shortest interval among enabled items for each location applies. Removing the
last item for a location cancels its requests; changing the interval restarts its
polling. Cosmetic changes do not restart requests.

Requests time out after 15 seconds. Before a successful reading, the label is
`Weather unavailable`. Failed requests retain the last reading and mark it `stale`;
the next successful request clears that flag. Stale means a refresh failed, not
that a particular age threshold was reached. `updatedAt` is the API's data timestamp
in UTC, not the time sbar fetched it. Current conditions are weather model estimates.

Use text templates to choose the displayed fields:

```json
{
  "id": "weather",
  "type": "weather",
  "weather": { "latitude": 51.5074, "longitude": -0.1278 },
  "text": "{{#available}}{{temperature}}{{temperatureUnit}} · {{condition}}{{#stale}} *{{/stale}}{{/available}}{{^available}}Weather unavailable{{/available}}"
}
```

| Field | Value |
| --- | --- |
| `temperature`, `feelsLike` | Rounded temperature in the selected unit |
| `temperatureUnit` | `°C` or `°F` |
| `humidity` | Rounded relative humidity percentage, without `%` |
| `windSpeed`, `windSpeedUnit` | Rounded speed and `km/h`, `mph`, `m/s`, or `kn` |
| `condition`, `weatherCode` | English condition description and Open-Meteo's WMO code |
| `isDay` | Whether the location is in daylight |
| `updatedAt` | Data timestamp in ISO 8601 UTC format |
| `available` | A reading exists, including a retained stale reading |
| `stale` | The last request failed and a previous reading is retained |
| `status` | `available`, `stale`, or `unavailable` |
| `value` | Default temperature label, or `Weather unavailable` |

Missing optional measurements render as empty strings. Clear and partly cloudy
conditions use day/night icons. Other weather codes map to cloud, fog, rain, snow,
sleet, and storm icons; unknown codes use `questionmark`. A top-level `symbol`
overrides the condition icon. Set `weather.showSymbol: false` for text only, or
`text: ""` for an icon alone.

Override individual conditions with `weather.symbols`. Strings are SF Symbol names;
glyph objects use a locally specified font or inherit `font` and `size` from the
symbols block:

```json
{
  "id": "weather",
  "type": "weather",
  "symbolPosition": "right",
  "weather": {
    "latitude": 53.4808,
    "longitude": -2.2426,
    "symbols": {
      "font": "Symbols Nerd Font Mono",
      "size": 16,
      "clearDay": "sun.max.fill",
      "clearNight": "moon.stars.fill",
      "overcastDay": "cloud.sun.fill",
      "overcastNight": "cloud.moon.fill",
      "rain": { "glyph": "\uf0e9" },
      "rainShowers": { "glyph": "\uf0e9" }
    }
  }
}
```

Supported keys are `clearDay`, `clearNight`, `partlyCloudyDay`,
`partlyCloudyNight`, `overcast`, `overcastDay`, `overcastNight`, `fog`, `drizzle`, `freezingDrizzle`, `rain`,
`freezingRain`, `snow`, `rainShowers`, `snowShowers`, `thunderstorm`,
`thunderstormHail`, `unknown`, and `unavailable`. Clear keys cover both clear and
mainly clear conditions. `unknown` covers unrecognised weather codes;
`unavailable` applies before a reading exists. Stale readings retain their
condition symbol.

For overcast conditions, `overcastDay` or `overcastNight` takes precedence over
`overcast`, based on the location's daylight flag. Omitted or null day/night entries
fall back to `overcast`, then the built-in cloud icon.

Other omitted or null entries keep the built-in symbols. A top-level `symbol` overrides
these settings; `weather.showSymbol: false` hides the symbol regardless of overrides.
Glyphs can override the shared font and size individually. See [symbols](../symbols.md)
for font requirements and the accepted size range.

Refresh policies control presentation snapshots separately from network polling.
Manual items receive their first successful reading, then retain it until triggered.
Changing coordinates clears the previous location's snapshot. Changing units formats
the existing snapshot without another request. Value events use each item ID and
report the default Celsius label, independent of templates and display units.

Weather data by [Open-Meteo](https://open-meteo.com/), licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). sbar rounds measurements,
converts units, and groups condition descriptions. This implementation uses the
keyless, non-commercial API. See [Open-Meteo's plans](https://open-meteo.com/en/pricing)
for service limits and commercial access; customer endpoints and API keys are not
supported in this version.

See [common item settings](../configuration.md#items),
[refresh policies](../configuration.md#refresh-policies), and [symbols](../symbols.md).
