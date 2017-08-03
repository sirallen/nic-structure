# Bank Holding Company Organizational Structures

Large banking and financial institutions are highly complex, but it is difficult to know just how complex. I made this application to visualize bank holding company structures and allow users to explore these institutions interactively. The size and organizational complexity of the largest among them—Goldman Sachs, Bank of America, J.P. Morgan Chase, and others—is stunning.

Application link:
[https://sirallen.shinyapps.io/nicStructure/](https://sirallen.shinyapps.io/nicStructure/)

The underlying data comes from the [National Information Center](https://www.ffiec.gov/nicpubweb/nicweb/SearchForm.aspx) but is available in pdf only:

<img src="https://github.com/sirallen/nic-structure/raw/master/img/screenCapture3.png">

The search form allows users to query institutional hierarchy reports as of a particular date, so in theory one could explore structural changes at daily frequency. To make the data more manageable at this early stage, I wrote scripts to download and parse the pdf files at end-of-quarter dates only. Each bank holding company is essentially a "network" of subsidiaries and can therefore be visualized using tools for network analysis.

You can read more about bank holding companies and the project in the `About` tab in the application.

### Screenshots:

<img src="https://github.com/sirallen/nic-structure/raw/master/img/screenCapture.png">

<img src="https://github.com/sirallen/nic-structure/raw/master/img/screenCapture2.png">

