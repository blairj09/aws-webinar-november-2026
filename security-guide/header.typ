// Posit brand touches for the PDF
#let posit-blue = rgb("#447099")
#let posit-gray = rgb("#404041")
#let posit-orange = rgb("#EE6331")
#let gray-300 = rgb("#717171")

#set text(fill: posit-gray)
#set par(justify: false)

// Body headings arrive as level 1 (Quarto shifts ## up one level for Typst)
#show heading: it => block(above: 1.4em, below: 0.65em, sticky: true)[
  #rect(width: 28pt, height: 2.5pt, fill: posit-orange, stroke: none)
  #v(-0.35em)
  #text(weight: 300, size: 15pt, fill: posit-gray, it.body)
]
#show strong: set text(weight: 700)
#show raw: set text(font: "Source Code Pro", size: 0.92em, fill: posit-gray)
#show link: set text(fill: posit-blue)
#show table.cell.where(y: 0): set text(fill: white, weight: 700)
#set table(
  fill: (_, y) => if y == 0 { posit-blue } else if calc.even(y) { rgb("#F3F6F8") } else { white },
  stroke: none,
  inset: 6pt,
)
#show table: set text(size: 9.5pt)
#show table: set par(justify: false)
#show figure.where(kind: table): set block(breakable: false)

#set page(footer: context [
  #set text(size: 8pt, fill: gray-300)
  Posit and Amazon Bedrock: a guide for security and platform teams
  #h(1fr)
  #counter(page).display()
])

// Flush-left title block with the full-color logo, page 1 only
#let posit-title(eyebrow: "", title: "", subtitle: "", date: "") = {
  image("assets/logos/posit-horiz-full-color.png", width: 1.1in, alt: "posit")
  v(1.4em)
  text(font: "Source Code Pro", size: 8pt, tracking: 0.08em, fill: posit-blue, upper(eyebrow))
  v(0.2em)
  text(weight: 300, size: 28pt, fill: posit-gray, title)
  v(-0.6em)
  text(weight: 700, size: 13pt, fill: posit-blue, subtitle)
  v(0.1em)
  text(size: 9pt, fill: gray-300, date)
  v(1em)
}
