function pluralize end

function pluralize(word::String,lang_code::String)
    lang_code = lowercase(lang_code)
    if lang_code == "eng"
        return Pluralize.ENG.pluralize(word)
    elseif lang_code == "fra"
        return Pluralize.FRA.pluralize(word)
    else
        error("Unsupported language[$lang_code]")
    end
end
