Shiny.addCustomMessageHandler('toggleHighlight', function(message) {
	if (message[0]) {
		//
		d3.select('#network svg g.zoom-layer').selectAll('g.node')
		  .style('opacity', function(d, i) {
		  	return (message[1].includes(i) ? .8 : .2)
		  });

		d3.select('#network svg g.zoom-layer').selectAll('line.link')
		  .style('opacity', function(d, i) {
		  	return (message[2].includes(i) ? .8 : .2)
		  });

	} else {
		// Set back to default opacity in forceNetwork()
		d3.select('#network svg g.zoom-layer').selectAll('g.node')
		  .style('opacity', .8);

		d3.select('#network svg g.zoom-layer').selectAll('line.link')
		  .style('opacity', .8);

	}

});

