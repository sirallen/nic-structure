---
output: html_document
---

## About

This application was made with R's <code>shiny</code>, <code>RMarkdown</code>, and <code>networkD3</code> packages and the <code>D3.js</code> JavaScript library.

A _bank holding company_ (BHC) is simply a firm that controls one or more banks. I've made an attempt here of visualizing the structures of such firms, with an eye toward portraying the scale and complexity of organization. (No analysis yet!) The underlying data come from the <a href='https://www.ffiec.gov/nicpubweb/nicweb/nichome.aspx' target='_blank'>National Information Center</a> (NIC) website, where holding company data can be queried via the Institution Search form. While the NIC reports data for U.S. companies only, many of them control a large number of international subsidiaries based in Europe, Asia, and elsewhere. Together, these BHCs control over $15 trillion in assets.

The figure below shows the total assets of the 20 largest BHCs as of the end of 2016:

<img src="figure/unnamed-chunk-1-1.png" title="plot of chunk unnamed-chunk-1" alt="plot of chunk unnamed-chunk-1" style="display: block; margin: auto;" />

The company structures are not strict hierarchies, in the sense that subsidiaries may be partially controlled by multiple parent companies (this is not uncommon). The definition of "control" (say, of company B by company A) is established in the instructions for the <a href='https://www.federalreserve.gov/apps/reportforms/reportdetail.aspx?sOoYJ+5BzDaGhRRQo6EFJQ==' target='_blank'>FR Y-10 Reporting Form</a> and includes such criteria as

* Ownership of 25% or more of any class of B's voting securities;

* Election of a majority of B's board of directors, trustees, general partners, or other high-level management positions;

* Ownership of "all or substantially all" of B's assets;

* ...
	
The forms also provide information on entity types and locations. Most entities are given nondescript labels of either "Domestic Entity Other" or "International Nonbank Sub of Domestic Entities"; others have more precise labels such as "Data Processing Servicer", "Securities Broker/Dealer", "Federal Savings Bank" and "Edge Corporation." (A glossary describing each of these types is available <a href='https://www.ffiec.gov/nicpubweb/content/help/institution%20type%20description.htm' target='_blank'>here</a>.) To simplify visualization, I've aggregated the types into eight broad categories as shown in the network legend. (A "nonbank", while classified as such, may engage in banking-related activities.) An entity's "location" refers to its physical location as reported in the FR Y-10.

### Research Questions
* How can this data be used to characterize the complexity of financial instutitions? (Is there a better measure than simply counting the number of controlled entities?)

* Besides simply being larger, how are the largest BHCs structurally different from medium- and small-sized ones?

* What are the (regulatory) incentives for structuring these institutions a certain way?

* How has the structure of these institutions changed over time? (More complex?)

* ...


### References
Avraham, D., P. Selvaggi and J. Vickery. "A Structural View of U.S. Bank Holding Companies." FRBNY Economic Policy Review, July 2012. (<a href='https://www.newyorkfed.org/medialibrary/media/research/epr/12v18n2/1207avra.pdf' target='_blank'>link</a>)



