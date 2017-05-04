Shiny.addCustomMessageHandler('jsondata', function(message) {
	var cities = message[0];
	var dfnet  = message[1];

	var d3io = d3.select('#d3io');

	if (typeof d3io[0] == 'undefined') {
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
var maxTier = 3;
var width = 1000;
var height = 670;

var projection = d3.geoOrthographic()
	.scale(300)
	.translate([width/2, height/2])
	.rotate([55,-40])
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


function createMap(svg) {
	var realFeatureSize = d3.extent(countries.geometries,
		function(d) {return d3.area(d);});

	var countryColor = d3.scaleQuantize()
						 .domain(realFeatureSize)
						 .range(colorbrewer.Reds[9]);

	var graticule = d3.geoGraticule();

	var mapZoom = d3.zoom().on('zoom', zoomed)

	svg.call(mapZoom)

	// code snippet from http://stackoverflow.com/questions/36614251/
	// dj3s-graticule-removed-when-rotation-is-done-in-orthographic-projection
	var λ = d3.scaleLinear()
        .domain([0, width])
        .range([-180, 180]);

    var φ = d3.scaleLinear()
        .domain([0, height])
        .range([90, -90]);

    var mapRotate = d3.drag().on('drag', rotated);

    function rotated(){
    	var r = projection.rotate();
    	var origin = {x: λ.invert(r[0]), y: φ.invert(r[1])};

        projection.rotate([λ(origin.x + d3.event.x), φ(origin.y + d3.event.y)]);
        svg.selectAll('path').attr('d', geoPath);
        //svg.selectAll('path.farc').attr('d', function(d) {return(swoosh(flying_arc(d)))});
    };

    svg.call(mapRotate);
    ////

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

	function zoomed(){
		var currentRotate = projection.rotate()[0]; // in [-360,360]
		var transform = d3.event.transform;
		var invert_old = projection.invert
		projection.scale(300*transform.k);
		d3.selectAll('path.graticule').datum(graticule).attr('d', geoPath);
		d3.selectAll('path').filter('.countries, .citynode, .arc').attr('d', geoPath);
		d3.selectAll('text.citylabel').each(function(d, i) {
			d.x = projection(invert_old([d.x,d.y]))[0]
			d.y = projection(invert_old([d.x,d.y]))[1]
		})
		//d3.selectAll('path.farc').attr('d', function(d) {return(swoosh(flying_arc(d)))});
	};

};

function updateMap(svg, cities, dfnet) {

	var links = [];
	var nodes = [];

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

	var arc = svg.selectAll('path.arc').data(links);

	arc.exit().remove();

	arc.enter()
	   .append('path')
	   .attr('class','arc')

/*	var farc = svg.selectAll('path.farc').data(links);

	farc.exit().remove();

	farc.enter()
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

	var allcities = svg.selectAll('g.cities').data(nodes);

	allcities.exit().remove();

	var city = allcities.enter()
		.append('g')
		.attr('class', 'cities')
		.on('mouseover',mouseover)
		.on('mouseout', mouseout);
	
	city.append('path')
		.attr('class','citynode')
		.attr('d', geoPath.pointRadius(3));

	city.append('text')
		.attr('class', 'citylabel')
		.attr('x', function(d) {return projection(d.coordinates)[0]})
		.attr('y', function(d) {return projection(d.coordinates)[1]})
		.text(function(d) {return d.citylabel});

	function mouseover(d){
		d3.select(this).select('path').transition()
		  .duration(750)
		  .attr('d', geoPath.pointRadius(5))
		d3.select(this).select('text').transition()
		  .duration(750)
		  .style('opacity', 1)
	};

	function mouseout(d){
		d3.select(this).select('path').transition()
		  .duration(750)
		  .attr('d', geoPath.pointRadius(3))
		d3.select(this).select('text').transition()
		  .duration(750)
		  .style('opacity', 0)
	};

	d3.selectAll('path.cities').attr('d', geoPath);
	d3.selectAll('path.arc').attr('d', geoPath);
	//d3.selectAll('path.farc').attr('d', function(d) {return(swoosh(flying_arc(d)))});
};

