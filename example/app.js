

var tigeocoderoffline = require('ti.geocoder.offline');

tigeocoderoffline.registerCountryInfo({
	url:  'countries.geo.json'
});

tigeocoderoffline.registerTerritoryInfoForCountryCode({
	countryCode:'US',
	url: 'us.states.geo.json'
});

tigeocoderoffline.reverseGeocoder(40.75773,-73.985708,function(e){
	console.log(JSON.stringify(e));
});
