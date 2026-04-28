#Project 8: Part 2: Baltimore City Open Data Analysis
`Rust`

##Chosen files = Liquor_Licenses.csv and Vacant_Building_Rehabs.csv
##Liquor Licenses contains information on the Liquor License Key, ```Corporate Key, License Class, Sub Class, License Number, License Date, License Year, License Fee, Certificate Number, License Status, Licensee First Name, Licensee Last Name, Trade Name, Corporation Name, Establishment Description, Day Per Week, Description, Address Street, Address Zip Code and 'ESRI_OID'
source URL = https://data.baltimorecity.gov/datasets/ae5ed61365e74579aea25656ac9ce45e_0/explore
```

##Vacant Building Rehabs contains the Object ID, Block, Lot, ```Permit Number, Date Issue, Date Issued, Existing Use, Proposed Use, Housing Market Typology 2017, Council District, Neighborhood, BlockLot and Address of vacant Buildings in Baltimore.
source URL = https://data.baltimorecity.gov/datasets/4db6d1e54e714a3e8125990a09d4623d_2/explore?location=39.296850%2C-76.620350%2C11
```

##Research Question: 
```How do local Liquor Licenses relate to Vacant Building Rehabs in Baltimore, Maryland? Do areas with more liquor licenses lead to more vacant building rehabs?```

##Answer/Output:
```The analysis reveals that the Liquor Licenses dataset groups data by zip code, 
while the Vacant Building Rehabs dataset groups data by neighborhood name.```

The correlation shows:
```- Zip code 21202 has 4,409 liquor licenses (highest) with 0 rehab projects
- Zip code 21231 has 3,072 liquor licenses with 0 rehab projects  
- Zip code 21201 has 3,031 liquor licenses with 0 rehab projects
- Neighborhoods like McElderry Park have 374 rehabs with 0 licenses
- Neighborhoods like Carrollton Ridge have 186 rehabs with 0 licenses

The lack of overlap indicates the datasets track geographic regions differently, 
making direct neighborhood-to-neighborhood comparison impossible.

##Limitations:
- The Liquor Licenses and Vacant Building Rehabs datasets use different geographic 
  identifiers (zip codes vs. neighborhood names), preventing direct correlation
- A proper analysis would require mapping zip codes to neighborhoods or vice versa
- The datasets may cover different time periods, affecting comparability
```



