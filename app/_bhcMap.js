(function(){

Shiny.addCustomMessageHandler('jsondata', function(message) {
	cities = message[0];
	dfnet  = message[1];

	width = d3.select('.tab-pane.active').node().getBoundingClientRect().width;

	var d3io = d3.select('#d3io');

	if (d3io['_groups'][0][0].children.length == 0) {
		// create svg, map
		var svg = d3io.append('svg')
					  .attr('width', width)
					  .attr('height', 670);

		createMap(svg);
	}

	var svg = d3io.select('svg');

	updateMap(svg, cities, dfnet, 5);

});

Shiny.addCustomMessageHandler('windowResize', function(message) {
	// when change in window size detected, update svg width & projection
	width = d3.select('.tab-pane.active').node().getBoundingClientRect().width;
	projection.translate([7*width/15, height/2]);

	var svg = d3.select('#d3io svg').attr('width', width);
	
	updatePaths(svg);
});

Shiny.addCustomMessageHandler('maxDist', function(message) {
	var maxTier = parseInt(message[0]) + 1;

	svg = d3.select('#d3io svg');

	updateMap(svg, cities, dfnet, maxTier);
});

// global vars (need to access in both createMap and updateMap)
var width = 1000;
var height = 670;
// initial scale and rotation (lng, lat)
var scale = 300;
var origin = {x: 55, y:-40};
var cities;
var dfnet;
var nodes;

var projection = d3.geoOrthographic()
	.scale(scale)
	.translate([2*width/5, height/2])
	.rotate([origin.x, origin.y])
	.center([0,0])
	.clipAngle(90);

var geoPath = d3.geoPath().projection(projection);

var graticule = d3.geoGraticule();


function createMap(svg) {
	// zoom AND rotate
	var mapZoom = d3.zoom().on('zoom', zoomed)

	svg.call(mapZoom)

	// code snippet from http://stackoverflow.com/questions/36614251/
	// dj3s-graticule-removed-when-rotation-is-done-in-orthographic-projection
	var λ = d3.scaleLinear()
        .domain([-width, width])
        .range([-180, 180]);

    var φ = d3.scaleLinear()
        .domain([-height, height])
        .range([90, -90]);

	svg.append('path')
	  .datum(graticule)
	  .attr('class','graticule')
	  .attr('d', geoPath);

	svg.selectAll('path').data(countries.geometries)
	  .enter()
	  .append('path')
	  .attr('d', geoPath)
	  .attr('class', 'countries')
	  .style('fill', function(d) {
	  	return "#FF9186"
	  });

	 //https://bl.ocks.org/emeeks/af3c0114adfd9ead565e6c0f4a9c494e
	function zoomed(){
		var transform = d3.event.transform;
		var r = {x: λ(transform.x), y: φ(transform.y)};
		var k = Math.sqrt(300/projection.scale());

		//console.log(transform);
		projection.scale(scale*transform.k)
				  .rotate([origin.x + r.x * k, origin.y + r.y]);

		d3.selectAll('path.graticule').datum(graticule).attr('d', geoPath);
		d3.selectAll('path').filter('.countries, .citynode, .arc').attr('d', geoPath);
		d3.selectAll('text.citylabel').data(nodes)
		  .attr('x', function(d) {return projection(d.coordinates)[0]})
		  .attr('y', function(d) {return projection(d.coordinates)[1]});
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

	city = svg.selectAll('g.cities').data(nodes).enter()
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

		d3.select(this).transition()
		  .duration(750)
		  .attr('d', geoPath.pointRadius(5));
		d3.select(this.parentNode).select('text').transition()
		  .duration(750)
		  .style('opacity', 1)
	};

	function mouseout(d){
		d3.select(this).transition()
		  .duration(750)
		  .attr('d', geoPath.pointRadius(3));
		d3.select(this.parentNode).select('text').transition()
		  .duration(750)
		  .style('opacity', 0)
	};

	svg.selectAll('path').filter('.citynode, .arc').attr('d', geoPath);
};

function updatePaths(svg) {
	svg.selectAll('path.graticule').datum(graticule).attr('d', geoPath);
	svg.selectAll('path').filter('.countries, .citynode, .arc').attr('d', geoPath);
};


})();