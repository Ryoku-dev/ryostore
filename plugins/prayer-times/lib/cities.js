// lib/cities.js — preset locations. Coordinates resolved once from OpenStreetMap
// (Nominatim) and frozen here; do not hand-edit lat/lon.
// ES5, no dependencies, runs in QML and node.

var CITIES = [
    { id: "baltimore", name: "Baltimore", country: "US", lat: 39.2909, lon: -76.6108, tz: "America/New_York", method: "isna" },
    { id: "new-york", name: "New York", country: "US", lat: 40.7127, lon: -74.006, tz: "America/New_York", method: "isna" },
    { id: "chicago", name: "Chicago", country: "US", lat: 41.8756, lon: -87.6244, tz: "America/Chicago", method: "isna" },
    { id: "houston", name: "Houston", country: "US", lat: 29.7589, lon: -95.3677, tz: "America/Chicago", method: "isna" },
    { id: "los-angeles", name: "Los Angeles", country: "US", lat: 34.0537, lon: -118.2428, tz: "America/Los_Angeles", method: "isna" },
    { id: "toronto", name: "Toronto", country: "CA", lat: 43.6535, lon: -79.3839, tz: "America/Toronto", method: "isna" },
    { id: "london", name: "London", country: "GB", lat: 51.5074, lon: -0.1278, tz: "Europe/London", method: "mwl" },
    { id: "manchester", name: "Manchester", country: "GB", lat: 53.4425, lon: -2.2325, tz: "Europe/London", method: "mwl" },
    { id: "birmingham", name: "Birmingham", country: "GB", lat: 52.4949, lon: -1.8518, tz: "Europe/London", method: "mwl" },
    { id: "paris", name: "Paris", country: "FR", lat: 48.8589, lon: 2.32, tz: "Europe/Paris", method: "mwl" },
    { id: "berlin", name: "Berlin", country: "DE", lat: 52.5174, lon: 13.3951, tz: "Europe/Berlin", method: "mwl" },
    { id: "amsterdam", name: "Amsterdam", country: "NL", lat: 52.3731, lon: 4.8925, tz: "Europe/Amsterdam", method: "mwl" },
    { id: "brussels", name: "Brussels", country: "BE", lat: 50.8467, lon: 4.3525, tz: "Europe/Brussels", method: "mwl" },
    { id: "stockholm", name: "Stockholm", country: "SE", lat: 59.3251, lon: 18.0711, tz: "Europe/Stockholm", method: "mwl" },
    { id: "oslo", name: "Oslo", country: "NO", lat: 59.9133, lon: 10.739, tz: "Europe/Oslo", method: "mwl" },
    { id: "madrid", name: "Madrid", country: "ES", lat: 40.4168, lon: -3.7035, tz: "Europe/Madrid", method: "mwl" },
    { id: "istanbul", name: "Istanbul", country: "TR", lat: 41.0064, lon: 28.9759, tz: "Europe/Istanbul", method: "diyanet" },
    { id: "cairo", name: "Cairo", country: "EG", lat: 30.0444, lon: 31.2357, tz: "Africa/Cairo", method: "egypt" },
    { id: "mecca", name: "Mecca", country: "SA", lat: 21.4208, lon: 39.8269, tz: "Asia/Riyadh", method: "ummalqura" },
    { id: "medina", name: "Medina", country: "SA", lat: 24.4712, lon: 39.6111, tz: "Asia/Riyadh", method: "ummalqura" },
    { id: "dubai", name: "Dubai", country: "AE", lat: 25.0743, lon: 55.1886, tz: "Asia/Dubai", method: "dubai" },
    { id: "karachi", name: "Karachi", country: "PK", lat: 24.8547, lon: 67.0207, tz: "Asia/Karachi", method: "karachi" },
    { id: "lahore", name: "Lahore", country: "PK", lat: 31.5657, lon: 74.3142, tz: "Asia/Karachi", method: "karachi" },
    { id: "delhi", name: "Delhi", country: "IN", lat: 28.6328, lon: 77.2198, tz: "Asia/Kolkata", method: "karachi" },
    { id: "mumbai", name: "Mumbai", country: "IN", lat: 19.055, lon: 72.8692, tz: "Asia/Kolkata", method: "karachi" },
    { id: "dhaka", name: "Dhaka", country: "BD", lat: 23.7644, lon: 90.389, tz: "Asia/Dhaka", method: "karachi" },
    { id: "jakarta", name: "Jakarta", country: "ID", lat: -6.1754, lon: 106.8272, tz: "Asia/Jakarta", method: "mwl" },
    { id: "kuala-lumpur", name: "Kuala Lumpur", country: "MY", lat: 3.1517, lon: 101.6942, tz: "Asia/Kuala_Lumpur", method: "mwl" },
    { id: "singapore", name: "Singapore", country: "SG", lat: 1.2899, lon: 103.8519, tz: "Asia/Singapore", method: "mwl" },
    { id: "sydney", name: "Sydney", country: "AU", lat: -33.8698, lon: 151.2083, tz: "Australia/Sydney", method: "mwl" },
    { id: "melbourne", name: "Melbourne", country: "AU", lat: -37.8142, lon: 144.9632, tz: "Australia/Melbourne", method: "mwl" },
    { id: "cape-town", name: "Cape Town", country: "ZA", lat: -33.9288, lon: 18.4172, tz: "Africa/Johannesburg", method: "mwl" },
    { id: "lagos", name: "Lagos", country: "NG", lat: 6.4551, lon: 3.3942, tz: "Africa/Lagos", method: "mwl" },
    { id: "nairobi", name: "Nairobi", country: "KE", lat: -1.3024, lon: 36.8289, tz: "Africa/Nairobi", method: "mwl" },
    { id: "tokyo", name: "Tokyo", country: "JP", lat: 35.6769, lon: 139.7639, tz: "Asia/Tokyo", method: "mwl" },
    { id: "sao-paulo", name: "Sao Paulo", country: "BR", lat: -23.5507, lon: -46.6334, tz: "America/Sao_Paulo", method: "mwl" }
];

function byId(id) {
    for (var i = 0; i < CITIES.length; i++) if (CITIES[i].id === id) return CITIES[i];
    return null;
}

// Map an IANA zone name (from /etc/localtime) to a preset. Exact match only:
// a wrong city is worse than an obvious one, so no fuzzy guessing here. When it
// misses, the caller keeps the fallback and flags the result as estimated so the
// UI can say "set your city".
var FALLBACK = "london";

function guess(tz) {
    if (tz) {
        for (var i = 0; i < CITIES.length; i++)
            if (CITIES[i].tz === tz) return { city: CITIES[i], exact: true };
    }
    return { city: byId(FALLBACK), exact: false };
}

function ids() {
    var out = [];
    for (var i = 0; i < CITIES.length; i++) out.push(CITIES[i].id);
    return out;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { CITIES: CITIES, byId: byId, guess: guess, ids: ids };
}
