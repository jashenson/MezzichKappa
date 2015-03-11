# MezzichKappa
###A Ruby implementation of Mezzich's Kappa

Version: 0.1a
mkappa computes Mezzich's Kappa for measuring the inter-rater reliability
for N raters with 1+ codes allowed per segment. For more details, see:

>Mezzich JE et al. Assessment of Agreement Among Several Raters Formulating
>Multiple Diagnoses. J Psych Res 1981 16(29):29-39.

Developer: Jared Shenson
Email: jared.shenson@gmail.com

###Usage
`ruby mkappa.rb rater1.csv rater2.csv [rater3.csv...]`

###Output
`mkappa_r[# of raters]_[timestamp].csv`

###Notes
- Files must be saved as __CSV__, one column per possible code, one row per segment. See sample datafile.
- Cell contents must be 0 or 1, indicating absence (0) or presence (1) of given code.
- A single header row may be included. It will be auto-detected and removed.
- May use as many raters as desired 
- Requires gem "Statsample" for calculation of kappa significance