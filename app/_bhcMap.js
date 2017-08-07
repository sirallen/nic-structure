(function(){

Shiny.addCustomMessageHandler('jsondata', function(message) {
	cities = message[0];
	dfnet  = message[1];

	width = d3.select('.tabbable').node().getBoundingClientRect().width;
	height = window.innerHeight - 110;

	var d3io = d3.select('#d3io');

	if (d3io['_groups'][0][0].children.length == 0) {
		// create svg, map
		var svg = d3io.append('svg')
					  .attr('width', width)
					  .attr('height', height);

		createMap(svg);
	}

	var svg = d3io.select('svg');

	updateMap(svg, cities, dfnet, 20);

});

Shiny.addCustomMessageHandler('windowResize', function(message) {
	// when change in window size detected, update svg width & projection
	width = d3.select('.tabbable').node().getBoundingClientRect().width;
	// don't use getBoundingClientRect().height -- it is constant (cannot specify height='100%')
	// but how do get this number 102 without hard-coding...?
	height = window.innerHeight - 110;
	//console.log('height:', height);
	projection.translate([3*width/7, height/2]);

	var svg = d3.select('#d3io svg')
				.attr('width', width)
				.attr('height', height);
	
	updatePaths(svg);
});

Shiny.addCustomMessageHandler('maxDist', function(message) {
	var maxTier = parseInt(message[0]) + 1;

	svg = d3.select('#d3io svg');

	updateMap(svg, cities, dfnet, maxTier);
});

// global vars (need to access in both createMap and updateMap)
var width = 1000,
    height = 670,
    // initial scale and rotation (lng, lat)
    scale = 300,
    origin = {x: 55, y:-40};

var cities, dfnet, nodes;

var projection = d3.geoOrthographic()
				   .scale(scale)
				   .translate([3*width/7, height/2])
				   .rotate([origin.x, origin.y])
				   .center([0,0])
				   .clipAngle(90);

var geoPath = d3.geoPath()
				.projection(projection);

var graticule = d3.geoGraticule();


function createMap(svg) {

	// code snippet from http://stackoverflow.com/questions/36614251
	var λ = d3.scaleLinear()
        	  .domain([-width, width])
        	  .range([-180, 180]),

        φ = d3.scaleLinear()
        	  .domain([-height, height])
        	  .range([90, -90]);

    var globe = svg.append('g').datum({x: 0, y: 0});

	globe.append('path')
	   .datum(graticule)
	   .attr('class','graticule')
	   .attr('d', geoPath);

	globe.selectAll('path')
	   .data(countries.geometries)
	   .enter()
	   .append('path')
	   .attr('d', geoPath)
	   .attr('class', 'countries')
	   .style('fill', '#FF9186');

	// https://stackoverflow.com/questions/43772975
	svg.call(d3.zoom().on('zoom', zoomed));
	globe.call(d3.drag().on('drag', dragged));


	function dragged(d){
		var r = {
			x: λ((d.x = d3.event.x)),
			y: φ((d.y = d3.event.y))
		};

    	projection.rotate([origin.x + r.x, origin.y + r.y]);
    	updatePaths(svg);
	};

	function zoomed(){
		var transform = d3.event.transform;
		var r = {x: λ(transform.x), y: φ(transform.y)};
		var k = Math.sqrt(300/projection.scale());

		projection.scale(scale*transform.k);

		updatePaths(svg);
	};

};

function updateMap(svg, cities, dfnet, maxTier) {

	var links = [];
	nodes = [];

	dfnet.forEach(function(d) {
		if (d.Tier <= maxTier) {
			links.push({
				type: 'LineString',
				coordinates: [
					[d['from.lng'], d['from.lat']],
					[d['to.lng'], d['to.lat']]
				],
				cityname: d['label']
			})
		}
	});

	svg.selectAll('path.arc').data([]).exit().remove();

	svg.selectAll('path.arc').data(links).enter()
	   .append('path')
	   .attr('class','arc');

	cities.forEach(function(d, i) {
		if (d.Tier <= maxTier) {
			nodes.push({
				type: 'Point',
				coordinates: [d.lng, d.lat],
				citylabel: d.label
			});
		}
	});

	svg.selectAll('g.cities').data([]).exit().remove();

	city = svg.selectAll('g.cities')
			  .data(nodes)
			  .enter()
			  .append('g')
			  .attr('class', 'cities');

	city.append('path')
		.attr('class','citynode')
		.attr('d', geoPath.pointRadius(3))
		.on('mouseover',mouseover)
		.on('mouseout', mouseout);

	city.append('text')
		.attr('class', 'citylabel')
		.attr('x', function(d) {return projection(d.coordinates)[0]})
		.attr('y', function(d) {return projection(d.coordinates)[1]})
		.text(function(d) {return d.citylabel})
		.style('pointer-events', 'none');

	function mouseover(d){
		var j = Array.from(d3.selectAll('g.cities')._groups[0]).indexOf(this.parentNode)
		// move <g> element to end so text appears in front
		this.parentNode.parentNode.appendChild(this.parentNode);
		// update nodes order to preserve correspondence with {<g>}
		//nodes.move(j, nodes.length)
		nodes.splice(nodes.length, 0, nodes.splice(j, 1)[0])

		d3.select(this)
		  .transition()
		  .duration(750)
		  .attr('d', geoPath.pointRadius(5));

		d3.select(this.parentNode).select('text')
		  .transition()
		  .duration(750)
		  .style('opacity', 1)
	};

	function mouseout(d){
		d3.select(this)
		  .transition()
		  .duration(750)
		  .attr('d', geoPath.pointRadius(3));

		d3.select(this.parentNode).select('text')
		  .transition()
		  .duration(750)
		  .style('opacity', 0)
	};

	svg.selectAll('path')
	   .filter('.citynode, .arc')
	   .attr('d', geoPath);
};

function updatePaths(svg) {
	svg.selectAll('path.graticule').datum(graticule).attr('d', geoPath);
	svg.selectAll('path').filter('.countries, .citynode, .arc').attr('d', geoPath);
	d3.selectAll('text.citylabel').data(nodes)
	  .attr('x', function(d) {return projection(d.coordinates)[0]})
	  .attr('y', function(d) {return projection(d.coordinates)[1]});
};


})();