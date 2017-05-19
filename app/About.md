---
output: html_document
---

## About

I made this application with R's <code>shiny</code>, <code>RMarkdown</code>, and <code>networkD3</code> packages and the <code>D3.js</code> JavaScript library; the source files are available on <a href='https://github.com/sirallen/nic-structure' target='_blank'>my Github page</a>. It's a work in progress, so don't mind the bugs!

<hr>

**Note:** For now, the available holding companies are those currently active with at least $100 billion in assets, though I plan to make more available soon.

<hr>

## Background

A _bank holding company_ (BHC) is simply a firm that controls one or more banks. I've made an attempt here to visualize the structures of such firms, with an eye toward portraying the scale and complexity of organization. (Actually, I include not only BHCs but also Financial Holding Companies, Savings & Loan Holding Companies, and Intermediate Holding Companies. These are all monitored by the Federal Reserve and are required to provide the structural data discussed below. See <a href='https://www.ffiec.gov/nicpubweb/content/help/institution%20type%20description.htm' target='_blank'>here</a> for definitions of these types.)

The underlying data come from the <a href='https://www.ffiec.gov/nicpubweb/nicweb/nichome.aspx' target='_blank'>National Information Center</a> (NIC) website, where holding company data can be queried via the Institution Search form. While the NIC reports data for U.S. companies only, some of them control a large number of international subsidiaries based in Europe, Asia, and elsewhere (think Bermuda, Nassau, the Caymans, and other idyllic vacation destinations). Some holding companies are themselves U.S. subsidiaries of foreign banking and financial organizations such as UBS, Barclays, and Credit Suisse. Together, these companies control over $15 trillion in assets.

The figure below shows the size (measured by total assets) of the 20 largest HCs as of the end of 2016, along with their share of assets among the 115 HCs with at least $10 billion in assets:

<img src="figure/unnamed-chunk-1-1.png" title="plot of chunk unnamed-chunk-1" alt="plot of chunk unnamed-chunk-1" style="display: block; margin: auto;" />

<hr>

**Note:** The structure data is not easy to access. For large institutions (i.e., the most interesting ones) the NIC search form returns only pdf documents, which must be processed to obtain usable data structures. (If the data were available in a user-friendly form in the past, as this 2012 New York Fed <a href='https://www.newyorkfed.org/medialibrary/media/research/epr/12v18n2/1207avra.pdf' target='_blank'>research article</a> suggests, this appears to be no longer the case.) Some regional Federal Reserve banks publish <a href='https://www.richmondfed.org/banking/supervision_and_regulation/fry6_reports' target='_blank'>FR Y-6 filings</a> with more detailed information about holding company structures, but as "unusable" pdf scans.

<hr>

The company structures are not strict hierarchies, in the sense that subsidiaries may be partially controlled by multiple parent companies (this is not uncommon). The definition of "control" (say, of company B by company A) is established in the instructions for the <a href='https://www.federalreserve.gov/apps/reportforms/reportdetail.aspx?sOoYJ+5BzDaGhRRQo6EFJQ==' target='_blank'>FR Y-10 Reporting Form</a> and includes such criteria as

* Ownership of 25% or more of any class of B's voting securities;

* Election of a majority of B's board of directors, trustees, general partners, or other high-level management positions;

* Ownership of "all or substantially all" of B's assets;

* ...
	
The forms also provide information on entity types and locations. Most entities are given nondescript labels of either "Domestic Entity Other" or "International Nonbank Subsidiary of Domestic Entities"; others have more precise labels such as "Data Processing Servicer", "Securities Broker/Dealer", "Federal Savings Bank" and "Edge Corporation." (A glossary describing each of these types is available <a href='https://www.ffiec.gov/nicpubweb/content/help/institution%20type%20description.htm' target='_blank'>here</a>.) To simplify visualization, I've aggregated the types into eight categories as shown in the network legend. (A "nonbank", while classified as such, may engage in banking-related activities.) An entity's "location" refers to its physical location as reported in the FR Y-10.

### Research Questions
* How can this data be used to characterize the complexity of financial instutitions? (Is there a better measure than simply counting the number of controlled entities?)

* Besides simply being larger, how are the largest HCs structurally different from medium- and small-sized ones?

* What are the (regulatory) incentives for structuring these institutions a certain way?

* How has the structure of these institutions changed over time? (More complex?)

* What activities do non-banks engage in?

* How are offshore financial centers (OFCs) incorporated into the structures?

* ...


### References
Avraham, D., P. Selvaggi and J. Vickery. "A Structural View of U.S. Bank Holding Companies." FRBNY Economic Policy Review, July 2012. (<a href='https://www.newyorkfed.org/medialibrary/media/research/epr/12v18n2/1207avra.pdf' target='_blank'>link</a>)

<hr>

