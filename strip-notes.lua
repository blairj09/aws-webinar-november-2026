-- Remove speaker notes (::: notes) so they are not shipped in the public build.
function Div(el)
  if el.classes:includes("notes") then
    return {}
  end
end
