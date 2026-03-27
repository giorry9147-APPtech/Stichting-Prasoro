jQuery(document).ready(function($) {
    "use strict";

    /*** =====================================
    * Menu
    * =====================================***/
    (function($) {
	    $.fn.menumaker = function(options) {
	        var cssmenu = $(this),
	            settings = $.extend({
	                format: "dropdown",
	                sticky: false
	            }, options);
	        return this.each(function() {
	            $(this).find(".button").on('click', function() {
	                $(this).toggleClass('menu-opened');
	                var mainmenu = $(this).next('ul');
	                if (mainmenu.hasClass('open')) {
	                    mainmenu.slideToggle().removeClass('open');
	                } else {
	                    mainmenu.slideToggle().addClass('open');
	                    if (settings.format === "dropdown") {
	                        mainmenu.find('ul').show();
	                    }
	                }
	            });
	            cssmenu.find('li ul').parent().addClass('has-sub');
	            var multiTg;
	            multiTg = function() {
	                cssmenu.find(".has-sub").prepend('<span class="submenu-button"></span>');
	                cssmenu.find('.submenu-button').on('click', function() {
	                    $(this).toggleClass('submenu-opened');
	                    if ($(this).siblings('ul').hasClass('open')) {
	                        $(this).siblings('ul').removeClass('open').slideToggle();
	                    } else {
	                        $(this).siblings('ul').addClass('open').slideToggle();
	                    }
	                });
	            };
	            if (settings.format === 'multitoggle') multiTg();
	            else cssmenu.addClass('dropdown');
	            if (settings.sticky === true) cssmenu.css('position', 'fixed');
	            var resizeFix;
	            resizeFix = function() {
	                var mediasize = 1000;
	                if ($(window).width() > mediasize) {
	                    cssmenu.find('ul').show();
	                }
	                if ($(window).width() <= mediasize) {
	                    cssmenu.find('ul').hide().removeClass('open');
	                }
	            };
	            resizeFix();
	            return $(window).on('resize', resizeFix);
	        });
	    };
	})(jQuery);
	 $("#easy-menu").menumaker({
        format: "multitoggle"
    });

    /*** =====================================
    * Slider
    * =====================================***/
    $(".slider-carousel").owlCarousel( {
        autoPlay: true,
        pagination: false,
        items: 1,
        itemsDesktop: [991, 1],
        itemsDesktopSmall: [667, 1],
        itemsTablet: [500, 1],
        itemsMobile: 1,
        navigation:true,
        navigationText: [
          "<i class='ion-ios-arrow-left'></i>",
          "<i class='ion-ios-arrow-right'></i>"
        ]
    });
    /*** =====================================
    * Rond Slider
    * =====================================***/
    function colorFullProgress() {
        var colorFullProgressActive = $('.colorfull-progress-active');
        var len = colorFullProgressActive.length;
        for (var i = 0; i < len; i++) {
            var roundId = '#' + colorFullProgressActive[i].id;
            $(roundId).circliful();
        }
    }
    if ($('.colorfull-progress-active') != null) {
        colorFullProgress();
    }
    /*** =====================================
    *  Event Counter
    * ===================================== ***/
	function showCountDown() {
		var eventsCountDown = $('.event-counter .sune-countdown');
		var len = eventsCountDown.length;

		for(var j=0; j < len; j++ ){
			var countDowns = $('.event-counter .sune-countdown');
			var countDown  = $('#'+countDowns[j].id);

			var endDateTime = countDown.attr( 'data-enddate' );

			var countDownFormat  = countDown.attr( 'data-format' );

			var endDateTimeArray = endDateTime.split(" ");
			var endDate = endDateTimeArray[0];
			var endTime = endDateTimeArray[1];

			endDate = endDate.split("-");
			endTime = endTime.split(":");

			var cUtcOffset = countDown.attr( 'data-utcoff' );
			var cDate 	  = parseInt(endDate[2]);
			var cMonth 	 = parseInt(endDate[1]) - 1;
			var cYear 	  = parseInt(endDate[0]);
			var cHour	  = parseInt(endTime[0]);
			var cMin	   = parseInt(endTime[1]);
			var cSec	   = parseInt(endTime[2]);

			countDown.countdown({
				until: $.countdown.UTCDate(cUtcOffset, cYear, cMonth, cDate, cHour, cMin, cSec),
				format: countDownFormat,
				padZeroes: true
			});

		}
    }
    if ($('.event-counter .sune-countdown') != null) {
        showCountDown();
    }
    /** =====================================
    *   Barfiller
    * ===================================== **/
    function suneBarfiller() {
        var suneBarfiller = document.getElementsByClassName('barfiller');
        var len = suneBarfiller.length;
        for (var i = 0; i < len; i++) {
            var suneBarId = '#' + suneBarfiller[i].id;
             $(suneBarId).barfiller();
        }
    }
    if (document.getElementsByClassName('barfiller') != null) {
        suneBarfiller();
    }
    /** =====================================
    * Hot Jobs Rating
    * =====================================**/
    function sunerating() {
        var suneRate = document.getElementsByClassName('sune-rating');
        var len = suneRate.length;
        for (var i = 0; i < len; i++) {
            var suneRateId = '#' + suneRate[i].id;
            var dataValue = $(suneRateId).attr('data-value');
            $(suneRateId).rateYo({
                  rating: dataValue,
                  starWidth: "13px",
            });
        }
    }
    if (document.getElementsByClassName('sune-rating') != null) {
        sunerating();
    }
    /** =====================================
    * Event Detail Calender
    * =====================================**/
    $('.calendar-day > .events').popover({
        container: '.sune-event-calender',
        content: 'Hello World',
        html: true,
        placement: 'top',
        template: '<div class="popover calendar-event-popover" role="tooltip"><div class="arrow"></div><h3 class="popover-title"></h3><div class="popover-content"></div></div>'
    });
    $('.calendar-day > .events').on('show.bs.popover', function () {
          var html = [
              '<div class="desc">'+$(this).find('div.desc').html()+'</div>',
          ];
        $(this).attr('data-content', html);
    });

   /** =====================================
    *   Search Box
    * =====================================**/
   $('.search-box .search-icon').on('click', function(e) {
        e.preventDefault();
        $('.top-search-input-wrap').addClass('show');

   });
   $(".top-search-input-wrap .top-search-overlay, .top-search-input-wrap .close-icon").on('click', function(){
        $('.top-search-input-wrap').removeClass('show');
   });

   $("#quote-carousel .carousel-inner .item:first-child").addClass('active');
   $("#quote-carousel .carousel-indicators li:first-child").addClass('active');
    /** =====================================
    *   Event Calender String Counter
    * ===================================== **/
    function suneStrigngGet() {
        var suneString = $('.day-list .calendar-day span');
        var len = suneString.length;
        for (var i = 0; i < len; i++) {
            var suneStId = '#' + suneString[i].id;
            var suneStringCount = $(suneStId).html().slice(0, 1);
            $(suneStId).html(suneStringCount);
        }
    }
    /** =====================================
    *   Diference Making Image Background
    * ===================================== **/
    var imageSourch = $('.deference-making-area .image img').attr( "src" );
    var imagePath = "url("+imageSourch+")";
    $('.deference-making-area .image').css({"background-image":imagePath});
    var deferenceMakingHeight = $(".deference-making-area").height();
    var windowHeight = $(window).height();
    var windowWidth = $(window).width();
    if (windowWidth < 768) {
        if ($('.day-list') != null) {
          suneStrigngGet();
      }
    }
    if (windowWidth > 991) {
        $(".deference-making-area .image").css({"height": deferenceMakingHeight});
    }
    $(window).on('resize',function(){
        if (windowWidth > 991) {
            $(".deference-making-area .image").css({"height": deferenceMakingHeight});
        }
    });
     $(window).on('load',function(){
        //$('#loading').fadeOut(500);
        if (windowWidth > 991) {
            $(".deference-making-area .image").css({"height": deferenceMakingHeight});
        }
    });
     // loading script
    window.onload = (function(onload) {
        return function(event) {
            onload && onload(event);

            $(".loading-overlay .spinner").fadeOut(300),
                $(".loading-overlay").fadeOut(300);
                $("body").css({
                    overflow: "auto",
                    height: "auto",
                    position: "relative"
                })
        }
    }(window.onload));

    /**
     * =====================================
     * Back to Top Button
     * =====================================
     */
	var showoffset = 70,
	offset_opacity = 1200,
	scroll_top_duration = 700,
	$back_to_top = $('.cd-top');
	$(window).on('scroll', function() {
		($(this).scrollTop() > showoffset) ? $back_to_top.addClass('cd-is-visible'): $back_to_top.removeClass('cd-is-visible cd-fade-out');
		if ($(this).scrollTop() > offset_opacity) {
			$back_to_top.addClass('cd-fade-out');
		}
	});

    $back_to_top.on('click', function(event) {
        event.preventDefault();
        $('body,html').animate({
            scrollTop: 0,
        }, scroll_top_duration);
    });

    /** =====================================
    * Counter
    * =====================================***/
    $('.sune-counter-count').counterUp({
        delay: 10,
        time: 1000
    });
});
