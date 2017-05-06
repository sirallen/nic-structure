Shiny.addCustomMessageHandler('jsondata', function(message) {
	var cities = message[0];
	var dfnet  = message[1];

	var d3io = d3.select('#d3io');

	if (d3io['_groups'][0][0].children.length == 0) {
		// create svg, map
		var svg = d3io.append('svg')
					  .attr('width', 1000)
					  .attr('height', 670);

		createMap(svg);
	}

	var svg = d3io.select('svg');

	updateMap(svg, cities, dfnet);

});

// global vars (need to access in both createMap and updateMap)
var maxTier = 5;
var width = 1000;
var height = 670;
// initial scale and rotation (lng, lat)
var scale = 300;
var origin = {x: 55, y:-40};
var nodes;
var links;

var projection = d3.geoOrthographic()
	.scale(scale)
	.translate([2*width/5, height/2])
	.rotate([origin.x, origin.y])
	.center([0,0])
	.clipAngle(90);

var geoPath = d3.geoPath().projection(projection);

// interpolation *function* for flying arcs
var swoosh = d3.line()
			   .x(function(d) {return d[0]})
			   .y(function(d) {return d[1]})
/*			   .interpolate('cardinal')
			   .tension(.0);*/

function cartesian(x) {
	// <lng, lat>
	var θ = x[0]*Math.PI/180;
	var φ = x[1]*Math.PI/180;

	var x = Math.cos(θ) * Math.cos(φ);
	var y = Math.sin(θ) * Math.cos(φ);
	var z = Math.sin(φ);
	//unit <x,y,z>
	result = [x, y, z];
	return result;
}

function clip_coord(c_, a, b) {
	var q = cartesian(c_);
	var p = math.cross(cartesian(a), cartesian(b));
	var pq = math.cross(p, q);
	var pq_n = math.norm(pq, 2);
	var t = pq.map(function(z) {return z/pq_n; });
	// <lng, lat>
	var t_ = [math.atan2(t[1], t[0]), math.atan2(t[2], math.sqrt(t[0]**2 + t[1]**2))];
	t_ = t_.map(function(z) {return z*180/Math.PI; });
	return t_;
}

function flying_arc(d) {
	var a = d.coordinates[0]; //source
	var b = d.coordinates[1]; //target
	//center <x, y>
	var c = projection.translate();
	//interpolator (function)
	var ab = d3.interpolate(a, b);
	//arc midpoint <x, y>
	var m = projection(ab(.5));

	//m --> apex <x, y>
	var scale = 1 + .3*ab.distance/Math.PI;
	m[0] = c[0] + (m[0] - c[0])*scale;
	m[1] = c[1] + (m[1] - c[1])*scale;

	//http://enrico.spinielli.net/understanding-great-circle-arcs_57/
	//center <lng, lat>
/*	var c_ = projection.invert(c);

	//clipping conditions
	if (math.max(d3.geo.distance(c_, a), d3.geo.distance(c_, b)) > Math.PI/2) {	// neither a nor b visible
		return null;
	}
	if (d3.geo.distance(c_, a) > Math.PI/2) {			// b visible, not a
		var t_ = clip_coord(c_, a, b);
		// proportion of arc length <a,b> visible
		var z = d3.geo.distance(b, t_) / ab.distance;
		t_ = projection(t_);
		var zscale = 1 + .3*ab.distance/Math.PI;

		t_[0] = c[0] + (t_[0] - c[0])*zscale;
		t_[1] = c[1] + (t_[1] - c[1])*zscale;

		if (z > .5) {
			var result = [t_, m, projection(b)];
		} else {
			var result = [m, t_, projection(b)];
		};
		return result;
	};
	if (d3.geo.distance(c_, b) > Math.PI/2) {			// a visible, not b
		var t_ = clip_coord(c_, a, b);
		var z = d3.geo.distance(a, t_) / ab.distance;
		t_ = projection(t_);
		var zscale = 1 + .3*ab.distance/Math.PI;

		t_[0] = c[0] + (t_[0] - c[0])*zscale;
		t_[1] = c[1] + (t_[1] - c[1])*zscale;

		if (z > .5) {
			var result = [projection(a), m, t_];
		} else {
			var result = [projection(a), t_, m];
		};
		return result;
	};*/

	var result = [projection(a), m, projection(b)];
	return result;
}

Array.prototype.move = function (from, to) {
  this.splice(to, 0, this.splice(from, 1)[0]);
};


function createMap(svg) {
	var realFeatureSize = d3.extent(countries.geometries,
		function(d) {return d3.area(d);});

	var countryColor = d3.scaleQuantize()
						 .domain(realFeatureSize)
						 .range(colorbrewer.Reds[9]);

	var graticule = d3.geoGraticule();

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
	  	return countryColor(d3.geoArea(d))
	  });

	 //https://bl.ocks.org/emeeks/af3c0114adfd9ead565e6c0f4a9c494e
	function zoomed(){
		var transform = d3.event.transform;
		var r = {x: λ(transform.x), y: φ(transform.y)};

		console.log(transform);
		projection.scale(scale*transform.k).rotate([origin.x + r.x, origin.y + r.y]);

		d3.selectAll('path.graticule').datum(graticule).attr('d', geoPath);
		d3.selectAll('path').filter('.countries, .citynode, .arc').attr('d', geoPath);
		d3.selectAll('text.citylabel').data(nodes)
		  .attr('x', function(d) {return projection(d.coordinates)[0]})
		  .attr('y', function(d) {return projection(d.coordinates)[1]})
		//d3.selectAll('path.farc').attr('d', function(d) {return(swoosh(flying_arc(d)))});
	};

};

function updateMap(svg, cities, dfnet) {

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
	   .attr('class','arc')

/*	svg.selectAll('path.farc').data([]).exit().remove();

	svg.selectAll('path.farc').data(links).enter()
	    .append('path')
	    .attr('class','farc')
	    .attr('d', function(d) {return(swoosh(flying_arc(d)))});*/

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
		nodes.move(j, nodes.length)

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

	d3.selectAll('path.citynode').attr('d', geoPath);
	d3.selectAll('path.arc').attr('d', geoPath);
	//d3.selectAll('path.farc').attr('d', function(d) {return(swoosh(flying_arc(d)))});
};
