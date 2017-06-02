Shiny.addCustomMessageHandler('toggleLegend', function(message) {
	if (message[0]) {
		document.getElementById('legend.style').innerText = 'g.legend {opacity: 1; pointer-events: none};';
	} else {
		document.getElementById('legend.style').innerText = 'g.legend {opacity: 0; pointer-events: none};';
	};

});

