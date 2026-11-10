// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)
        show figure.where(kind: kind): set figure(outlined: false)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  lof: false,
  lof-title: none,
  lot: false,
  lot-title: none,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  if lof {
    block(above: 0em, below: 2em)[
    #outline(title: lof-title, target: figure.where(kind: "quarto-float-fig"));
    ]
  }

  if lot {
    block(above: 0em, below: 2em)[
    #outline(title: lot-title, target: figure.where(kind: "quarto-float-tbl"));
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

= Using tidymodels in forest modeling workflows
<using-tidymodels-in-forest-modeling-workflows>
#block[
#block[
#align(center)[#box(image("https://tidymodels.tidymodels.org/logo.png"))]
#block[
#block[
Matt Russell

11 November 2026

]
#block[
#box(image("images/arbor_block2.png", width: 2.08333in, alt: "Arbor Analytics logo"))

]
]
]
#block[
#align(center)[#box(image("https://arbor-analytics.com/post/2025-05-27-accounting-for-defect-tree-biomass/ash_tree.jpg"))]
]
]
== Workshop resources
<workshop-resources>
#block[
#block[
- Welcome!
- Access the code, data and slides from #link("https://github.com/mbrussell/tidymodels/")
- We'll conclude by 3:00 p.m.

]
#block[
#align(center)[#box(image("images/qr-code-github.png", width: 70.0%))]
]
]
== Objectives
<objectives>
+ Understand the core packages and functions within tidymodels and how they can be used for common forest modeling scenarios.
+ Be able to design workflows that allow for training and testing models to evaluate and validate their performance.
+ Understand how to work with model output in an efficient manner so that results can be easily interpreted and visualized.

== tidymodels
<tidymodels>
#block[
#block[
#box(image("slides_files/mediabag/logo.png"))

]
#block[

#block[
#Skylighting(([#FunctionTok("install.packages");#NormalTok("(");#StringTok("\"tidymodels\"");#NormalTok(")");],
[#FunctionTok("library");#NormalTok("(tidymodels)");],));
]

- A collection of R packages for modeling (e.g., regression, machine learning)
- Uses tidyverse principles (good for data wrangling and visualization)
- Sets up workflows that are reproducible

]
]
== tidymodels is a collection of many packages
<tidymodels-is-a-collection-of-many-packages>
#block[
#block[
There are \~8 core packages in #NormalTok("tidymodels");. We'll focus on:

- #NormalTok("rsample"); - Splits data into training and testing sets
- #NormalTok("recipes"); - Preprocesses data
- #NormalTok("parsnip"); - Specifies models
- #NormalTok("yardstick"); - Assesses model performance
- #NormalTok("broom"); - Converts model objects into tidy datasets

]
#block[
#align(center)[#box(image("images/tidymodels-pkgs.png", width: 100.0%))]
Image: rpubs.com/chenx/tidymodels\_tutorial

]
]
== Our dataset
<our-dataset>
#block[
#block[
- NSVB\_TREE.csv
- Tree measurements of volume, weight, and physical properties (#emph[n] = 12,000+)
- Biomass components for stem wood, bark, branches, and foliage
- Available from #link("https://data.lib.vt.edu/articles/dataset/LegacyTreeData_v2/22582432")[Virginia Tech's Data Repository]

]
#block[
#align(center)[#box(image("images/white-pine-logs.jpg", width: 100.0%))]
]
]
== Goal: Predict aboveground tree biomass for various species groups
<goal-predict-aboveground-tree-biomass-for-various-species-groups>
- There are 114 different species in the dataset
- We will group species into one of 10 Jenkins species groups.

#block[
#block[
#block[
#Skylighting(([#NormalTok("tree ");#SpecialCharTok("|>");#NormalTok("  ");],
[#NormalTok("  ");#FunctionTok("group_by");#NormalTok("(COMMON_NAME) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("summarize");#NormalTok("(");#StringTok("`");#AttributeTok("Num trees");#StringTok("`");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#FunctionTok("n");#NormalTok("(),");],
[#NormalTok("            ");#StringTok("`");#AttributeTok("Mean DBH (cm)");#StringTok("`");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#FunctionTok("round");#NormalTok("(");#FunctionTok("mean");#NormalTok("(dbh_cm, ");#AttributeTok("na.rm=");#NormalTok("T), ");#DecValTok("1");#NormalTok("),");],
[#NormalTok("            ");#StringTok("`");#AttributeTok("Min DBH (cm)");#StringTok("`");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#FunctionTok("min");#NormalTok("(dbh_cm, ");#AttributeTok("na.rm=");#NormalTok("T),");],
[#NormalTok("            ");#StringTok("`");#AttributeTok("Max DBH (cm)");#StringTok("`");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#FunctionTok("max");#NormalTok("(dbh_cm, ");#AttributeTok("na.rm=");#NormalTok("T),");],
[#NormalTok("            ");#StringTok("`");#AttributeTok("Mean weight (kg)");#StringTok("`");#OtherTok("=");#NormalTok(" ");#FunctionTok("round");#NormalTok("(");#FunctionTok("mean");#NormalTok("(bm_kg, ");#AttributeTok("na.rm=");#NormalTok("T), ");#DecValTok("1");#NormalTok("),");],
[#NormalTok("            ");#StringTok("`");#AttributeTok("Min weight (kg)");#StringTok("`");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#FunctionTok("min");#NormalTok("(bm_kg, ");#AttributeTok("na.rm=");#NormalTok("T),");],
[#NormalTok("            ");#StringTok("`");#AttributeTok("Max weight (kg)");#StringTok("`");#NormalTok(" ");#OtherTok("=");#NormalTok(" ");#FunctionTok("max");#NormalTok("(bm_kg, ");#AttributeTok("na.rm=");#NormalTok("T)) ");#SpecialCharTok("|>");#NormalTok(" ");],
[#NormalTok("  ");#FunctionTok("arrange");#NormalTok("(");#FunctionTok("desc");#NormalTok("(");#StringTok("`");#AttributeTok("Num trees");#StringTok("`");#NormalTok("))");],));
]
]
#block[
#align(center)[#box(image("images/species_list.png", width: 100.0%))]
]
]
== Task 1: Explore the biomass dataset
<task-1-explore-the-biomass-dataset>
#block[
#block[
- Our primary variable of interest is #NormalTok("TT_DW_ADJ"); (Aboveground wood, bark, and foliage dry weight)
- See the NSVB Data Dictionary for more information on the variables in the dataset.
- Head to #NormalTok("tidymodels_notebook.qmd"); to explore to get started.

]
#block[
#align(center)[#box(image("images/biomass_plot.png", width: 100.0%))]
]
]
== The modeling
<the-modeling>
#table(
  columns: (58.82%, 41.18%),
  align: (left,left,),
  table.header([Exercise], [Functions],),
  table.hline(),
  [Refit a single species group], [#NormalTok("workflow()");, #NormalTok("fit()");, #NormalTok("tidy()");],
  [Refit to all species groups], [#NormalTok("nest()");, #NormalTok("map()");],
  [Compare fits to original Jenkins equation], [Joining and interpreting coefficients],
  [Predict biomass on new sites], [Back-transformation],
)
== The Jenkins equation form
<the-jenkins-equation-form>
$ ln\(b m\)= beta_0 + beta_1 ln\(d b h\) $

or equivalently, on the original scale:

$ b m = e^(beta_0 + beta_1 ln\(d b h\)) = e^(beta_0) dot.op d b h^(beta_1) $

#block[
#block[
- $b m$ = total aboveground dry biomass (kg)
- $d b h$ = diameter at breast height (cm)
- $beta_0\,beta_1$ = coefficients, #strong[one pair per species group]

]
#block[
- Linear on the log-log scale
- We can use #NormalTok("linear_reg()");

]
]
#block[
#callout(
body: 
[
#Skylighting(([#FunctionTok("workflow");#NormalTok("(ln_bm ");#SpecialCharTok("~");#NormalTok(" ln_dbh, ");#FunctionTok("linear_reg");#NormalTok("())");],));
]
, 
title: 
[
In tidymodels:
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
== #NormalTok("broom");: turns model objects into tidy datasets
<broom-turns-model-objects-into-tidy-datasets>
#block[
#block[
- Model objects (like #NormalTok("lm");) store results in nested lists that are awkward to work with
- #NormalTok("broom"); converts them into #strong[tibbles], so you can use the tidyverse
- Three main functions:

#table(
  columns: 3,
  align: (left,left,left,),
  table.header([#NormalTok("broom"); function], [Provides], [],),
  table.hline(),
  [#NormalTok("tidy()");], [Coefficients, standard errors, p-values], [],
  [#NormalTok("glance()");], [Fit statistics (e.g., R-squared, AIC)], [],
  [#NormalTok("augment()");], [Predictions and residuals], [],
)
]
#block[
-

]
]
== Task 2: Refit the Jenkins et al.~2003 equation
<task-2-refit-the-jenkins-et-al.-2003-equation>
#block[
#block[
- Fit #NormalTok("ln(biomass) ~ ln(DBH)"); separately for each Jenkins species group
- Compare your coefficients to the published values in #NormalTok("REF_SPECIES");
- Predict biomass on held-out sites and calculate bias in kg

]
#block[
#align(center)[#box(image("images/jenkins_eqns.png", width: 100.0%))]
]
]
== Random forests
<random-forests>
#block[
#block[
- First, take several small samples of the data
- Any observations that aren't taken are called "out-of-bag" samples
- Build a set of regression trees on the sampled data and calculate mean square error

]
#block[
#align(center)[#box(image("images/rf_bootstrap.png", width: 100.0%))]
]
]
== Variable importance in random forests
<variable-importance-in-random-forests>
#block[
#block[
- If the percent increase in MSE after removing the variable is large, it's an important variable!
- If the percent increase in MSE is small, it's less important

]
#block[
#align(center)[#box(image("images/rf_importance.png", width: 100.0%))]
]
]
== Key arguments in #NormalTok("rand_forest()");
<key-arguments-in-rand_forest>
#block[
#block[

#table(
  columns: (33.33%, 30%, 36.67%),
  align: (left,left,left,),
  table.header([Argument], [Meaning], [Our value],),
  table.hline(),
  [#NormalTok("trees");], [Number of trees in the forest], [e.g., 500],
  [#NormalTok("mtry");], [Predictors considered at each split], [1 or 2 (DBH or species group)],
  [#NormalTok("min_n");], [Minimum observations to split a node], [e.g., 5],
)
]
#block[

#block[
#Skylighting(([#FunctionTok("rand_forest");#NormalTok("(");],
[#NormalTok("  ");#AttributeTok("trees =");#NormalTok(" ");#DecValTok("500");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("mtry  =");#NormalTok(" ");#DecValTok("2");#NormalTok(",");],
[#NormalTok("  ");#AttributeTok("min_n =");#NormalTok(" ");#DecValTok("5");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("set_engine");#NormalTok("(");#StringTok("\"ranger\"");#NormalTok(",");],
[#NormalTok("             ");#AttributeTok("importance =");#NormalTok(" ");#StringTok("\"permutation\"");#NormalTok(") ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("set_mode");#NormalTok("(");#StringTok("\"regression\"");#NormalTok(")");],));
]
]
]
== Task 3: Random forests to predict tree biomass
<task-3-random-forests-to-predict-tree-biomass>
#block[
#block[
- Specify a random forest with #NormalTok("rand_forest()"); and the #NormalTok("ranger"); engine
- Fit it to the #strong[same training data and predictors] as the Jenkins refit
- Evaluate the model on held-out sites

]
#block[
#align(center)[#box(image("images/tree-diagram.png", width: 100.0%))]
]
]
== How to compare models?
<how-to-compare-models>
#block[
#block[
#table(
  columns: 2,
  align: (left,left,),
  table.header([Metric], [Measures],),
  table.hline(),
  [#strong[RMSE] (kg)], [Typical error, penalizes big misses],
  [#strong[MAE] (kg)], [Mean absolute error],
  [#strong[Bias] (%)], [Systematic over- or under-prediction],
)
- Compute metrics on the original (kg) scale
- Use the held-out (test) data

]
#block[
#align(center)[#box(image("images/yardstick.png", width: 100.0%))]
]
]
== The #NormalTok("yardstick"); package
<the-yardstick-package>
#block[
#block[
- Provides metric functions, e.g., #NormalTok("rmse()");, #NormalTok("mae()");, #NormalTok("rsq()");
- #NormalTok("metric_set()"); bundles all metrics using a single function
- Outputs a dataset (i.e., a "tidy tibble")

#block[
#Skylighting(([#CommentTok("# One metric at a time");],
[#FunctionTok("rmse");#NormalTok("(test_pred, ");#AttributeTok("truth =");#NormalTok(" bm_kg,");],
[#NormalTok("     ");#AttributeTok("estimate =");#NormalTok(" rf_kg)");],
[],
[#CommentTok("# A bundle of metrics");],
[#NormalTok("biomass_metrics ");#OtherTok("<-");#NormalTok(" ");#FunctionTok("metric_set");#NormalTok("(rmse, mae)");],
[],
[#CommentTok("# Call it like any yardstick metric");],
[#NormalTok("test_pred ");#SpecialCharTok("|>");],
[#NormalTok("  ");#FunctionTok("biomass_metrics");#NormalTok("(");#AttributeTok("truth =");#NormalTok(" bm_kg,");],
[#NormalTok("                  ");#AttributeTok("estimate =");#NormalTok(" rf_kg)");],));
]
]
#block[
#align(center)[#box(image("images/yardstick.png", width: 100.0%))]
]
]
== Task 4: Compare Jenkins refit to random forests
<task-4-compare-jenkins-refit-to-random-forests>
#block[
#block[
- Combine predictions from the Jenkins refit and the random forests
- Calculate bias and error by Jenkins group with #NormalTok("yardstick"); package
- Visualize where each model over- or under-predicts

]
#block[
#box(image("images/jenkins_eqns.png", width: 100.0%, alt: "Plot of tree biomass by diameter for nine species groups.")) Image: Jenkins et al.~2003

]
]
== Sidequests!
<sidequests>
#block[
#block[
- See #NormalTok("tidymodels_notebook.qmd"); for additional exercises to tackle with the data.

]
#block[
#align(center)[#box(image("images/bog-canoe.jpg", width: 100.0%))]
]
]
== More #NormalTok("tidymodels"); resources
<more-tidymodels-resources>
- #link("https://www.tidymodels.org/start/")[tidymodels.org]
- #link("https://www.tmwr.org/")[#emph[Tidy Modeling with R]] (book)
- A few Arbor Analytics blog posts on tidymodels:
  - #link("https://arbor-analytics.com/post/2024-07-22-regression-with-tidymodels/index.html")[Predicting tree biomass for many species]
  - #link("https://arbor-analytics.com/post/2023-04-12-bootstrapped-resampling-estimates-to-predict-tree-height/index.html#bootstrapping-regressions-with-tidymodels")[Bootstrapped resampling to model tree biomass]
