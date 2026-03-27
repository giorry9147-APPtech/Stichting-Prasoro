(function ($) {
    "use strict";
    $(document).ready(function () {
        $(window).trigger("resize");
		$(".sune-gmap3").each(function(){
		   init_map( $(this).find('#sune-gmap3-canvas'));
		});       
    });

})(jQuery); // End of use strict


/* ---------------------------------------------
 Google map
 --------------------------------------------- */
function init_map(gmMapDiv) {
    (function ($) {
        if (gmMapDiv.length) {

            var gmCenterAddress = gmMapDiv.attr("data-address");
            var gmMarkerAddress = gmMapDiv.attr("data-address");
            var markar_icon 	 = gmMapDiv.attr("data-marker-icon" );		
			var lat_val  		 = gmMapDiv.attr("data-lat" );
			var long_val 		= gmMapDiv.attr("data-long" );
			var zoom 			= gmMapDiv.attr("data-zoom" );
			
            gmMapDiv.gmap3({
                action: "init",
                marker: {
					address: gmCenterAddress,
					latLng: [lat_val, long_val],
					
                    options: {
                        icon: markar_icon
                    }
                },
                map: {
                    options: {
                        zoom: parseInt(zoom),
                        zoomControl: true,
                        zoomControlOptions: {
                            style: google.maps.ZoomControlStyle.SMALL
                        },
                        mapTypeControl: false,
                        scaleControl: false,
                        scrollwheel: false,
                        streetViewControl: true,
                        draggable: true,
                        styles: [{
                            "featureType": "water",
                            "elementType": "geometry.fill",
                            "stylers": [{
                                "color": "#d3d3d3"
                            }]
                        }, {
                            "featureType": "transit",
                            "stylers": [{
                                "color": "#808080"
                            }, {
                                "visibility": "off"
                            }]
                        }, {
                            "featureType": "road.highway",
                            "elementType": "geometry.stroke",
                            "stylers": [{
                                "visibility": "on"
                            }, {
                                "color": "#b3b3b3"
                            }]
                        }, {
                            "featureType": "road.highway",
                            "elementType": "geometry.fill",
                            "stylers": [{
                                "color": "#ffffff"
                            }]
                        }, {
                            "featureType": "road.local",
                            "elementType": "geometry.fill",
                            "stylers": [{
                                "visibility": "on"
                            }, {
                                "color": "#ffffff"
                            }, {
                                "weight": 1.8
                            }]
                        }, {
                            "featureType": "road.local",
                            "elementType": "geometry.stroke",
                            "stylers": [{
                                "color": "#d7d7d7"
                            }]
                        }, {
                            "featureType": "poi",
                            "elementType": "geometry.fill",
                            "stylers": [{
                                "visibility": "on"
                            }, {
                                "color": "#ebebeb"
                            }]
                        }, {
                            "featureType": "administrative",
                            "elementType": "geometry",
                            "stylers": [{
                                "color": "#a7a7a7"
                            }]
                        }, {
                            "featureType": "road.arterial",
                            "elementType": "geometry.fill",
                            "stylers": [{
                                "color": "#ffffff"
                            }]
                        }, {
                            "featureType": "road.arterial",
                            "elementType": "geometry.fill",
                            "stylers": [{
                                "color": "#ffffff"
                            }]
                        }, {
                            "featureType": "landscape",
                            "elementType": "geometry.fill",
                            "stylers": [{
                                "visibility": "on"
                            }, {
                                "color": "#efefef"
                            }]
                        }, {
                            "featureType": "road",
                            "elementType": "labels.text.fill",
                            "stylers": [{
                                "color": "#696969"
                            }]
                        }, {
                            "featureType": "administrative",
                            "elementType": "labels.text.fill",
                            "stylers": [{
                                "visibility": "on"
                            }, {
                                "color": "#737373"
                            }]
                        }, {
                            "featureType": "poi",
                            "elementType": "labels.icon",
                            "stylers": [{
                                "visibility": "off"
                            }]
                        }, {
                            "featureType": "poi",
                            "elementType": "labels",
                            "stylers": [{
                                "visibility": "off"
                            }]
                        }, {
                            "featureType": "road.arterial",
                            "elementType": "geometry.stroke",
                            "stylers": [{
                                "color": "#d6d6d6"
                            }]
                        }, {
                            "featureType": "road",
                            "elementType": "labels.icon",
                            "stylers": [{
                                "visibility": "off"
                            }]
                        }, {}, {
                            "featureType": "poi",
                            "elementType": "geometry.fill",
                            "stylers": [{
                                "color": "#dadada"
                            }]
                        }]
                    }
                }
            });
        }
    })(jQuery);
}