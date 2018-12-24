(function(){

Shiny.addCustomMessageHandler('jsondata', function(message) {
    cities = message[0];
    dfnet  = message[1];

    width = d3.select('.tabbable').node().getBoundingClientRect().width;
    /*Don't use getBoundingClientRect().height -- it is constant
    but how do get this number 110 without hard-coding...?*/
    height = window.innerHeight - 110;

    var d3io = d3.select('#d3io');

    if (d3io.select('svg').empty()) {
        var svg = d3io.append('svg')
                      .attr('width', width)
                      .attr('height', height);

        createMap(svg);
    };

    var svg = d3io.select('svg');

    updateMap(svg, cities, dfnet, 20);

});

Shiny.addCustomMessageHandler('windowResize', function(message) {
    /*When change in window size detected, update svg width & projection*/
    width = d3.select('.tabbable').node().getBoundingClientRect().width;
    height = window.innerHeight - 110;
    
    projection.translate([width/2, height/2]);

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

/*Vars that I need to access in both createMap() and updateMap().
These are not accessible globally (i.e., in the console or in
other scripts) since this script wrapped by a function call. See
https://stackoverflow.com/questions/5493997*/
var width = 1000,
    height = 670,
    init_scale = 300,
    init_rotate = [55, -40]; /*sets the initial "origin" at <-55, 40> in <lng, lat>*/

var cities, dfnet, nodes;

var projection = d3.geoOrthographic()
                   .scale(init_scale)
                   .translate([width/2, height/2])
                   .rotate(init_rotate)
                   .center([0, 0])
                   .clipAngle(90);

var geoPath = d3.geoPath()
                .projection(projection);

var graticule = d3.geoGraticule();


function createMap(svg) {

    /*http://stackoverflow.com/questions/36614251*/
    var globe = svg.append('g').datum({x: 0, y: 0});
    svg.append('g').attr('class', 'arcGroup');
    svg.append('g').attr('class', 'nodeGroup');

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

    var λ = d3.scaleLinear()
              .domain([-width, width])
              .range([-180, 180]),

        φ = d3.scaleLinear()
              .domain([-height, height])
              .range([90, -90]);

    /*https://stackoverflow.com/questions/43772975*/
    svg.call(
        d3.zoom()
          .on('zoom', zoomed)
          .on('end', function() {
            /*Adjust sensitivity of scale functions (for dragged())*/
            var s = init_scale / projection.scale();

            λ.range([-180*s, 180*s]);
            φ.range([90*s, -90*s]);
          })
    ).on('dblclick.zoom', null);
    
    globe.call(
        d3.drag()
          .on('drag', dragged)
    );

    function dragged() {
        /*This function is effectively called at high
        frequency for the duration of the drag event*/
        var r = projection.rotate();
        projection.rotate([r[0] + λ(d3.event.dx), r[1] + φ(d3.event.dy)]);
        updatePaths(svg);
    };

    var old_k = 1;

    function zoomed() {
        var transform = d3.event.transform;
        var r = projection.rotate();
        var scf = transform.k / old_k;
        old_k = transform.k;

        /*mpos: Mouse position/coordinates (x, y),
        center: Center of the canvas (w/2, h/2)*/
        var mpos = d3.mouse(this);
        var center = projection.translate();

        projection.scale(init_scale*transform.k);

        /*Rotate the globe so the same point remains under the mouse before &
        after zooming. Maybe need to make some adjustments so this is more
        effective when the mouse is near the outer edge

        p0: <lng, lat> of the point under the mouse before zooming
        p1: <lng, lat> of the point under the mouse after zooming*/
        var p0 = projection.invert([center[0] + scf*(mpos[0] - center[0]), center[1] + scf*(mpos[1] - center[1])]);
        var p1 = projection.invert(mpos);

        projection.rotate([r[0] + p1[0] - p0[0], r[1] + p1[1] - p0[1]]);

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

    var arcGroup = svg.select('g.arcGroup');
    var nodeGroup = svg.select('g.nodeGroup');

    arcGroup.selectAll('path.arc')
            .data([])
            .exit()
            .remove();

    arcGroup.selectAll('path.arc')
            .data(links)
            .enter()
            .append('path')
            .attr('class','arc');

    cities.forEach(function(d, i) {
        if (d.Tier <= maxTier) {
            nodes.push({
                type: 'Point',
                coordinates: [d.lng, d.lat],
                citylabel: d.label.toUpperCase()
            });
        }
    });

    nodeGroup.selectAll('g.city')
             .data([])
             .exit()
             .remove();

    /*nodeGroup now refers to the set of g.city elements
    within <g class='node'>*/
    nodeGroup = nodeGroup.selectAll('g.city')
                         .data(nodes)
                         .enter()
                         .append('g')
                         .attr('class', 'city');

    nodeGroup.append('path')
             .attr('class','citynode')
             .attr('d', geoPath.pointRadius(3))
             .on('mouseover',mouseover)
             .on('mouseout', mouseout);

    nodeGroup.append('text')
             .attr('class', 'citylabel')
             .attr('x', function(d) {return projection(d.coordinates)[0]})
             .attr('y', function(d) {return projection(d.coordinates)[1]})
             .text(function(d) {return d.citylabel})
             .style('pointer-events', 'none');

    function mouseover(d){
        var j = Array.from(d3.selectAll('g.city')._groups[0]).indexOf(this.parentNode)
        /*Move <g> element to end so text appears in front, then update nodes order
        to preserve correspondence with {<g>}*/
        this.parentNode.parentNode.appendChild(this.parentNode);
        nodes.splice(nodes.length, 0, nodes.splice(j, 1)[0]);

        d3.select(this)
          .transition()
          .duration(750)
          .attr('d', geoPath.pointRadius(5));

        d3.select(this.parentNode).select('text')
          .transition()
          .duration(750)
          .attr('dx', 13)
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
          .attr('dx', 0)
          .style('opacity', 0)
    };

    svg.selectAll('path')
       .filter('.citynode, .arc')
       .attr('d', geoPath);
};

function updatePaths(svg) {
    d3.selectAll('text.citylabel').data(nodes)
      .attr('x', function(d) {return projection(d.coordinates)[0]})
      .attr('y', function(d) {return projection(d.coordinates)[1]});
    svg.selectAll('path.graticule').datum(graticule).attr('d', geoPath);
    svg.selectAll('path').filter('.countries, .citynode, .arc').attr('d', geoPath);
};


})();