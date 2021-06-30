function pluralize(word::String)
    if (endswith(word,"eau")
     || endswith(word,"eu")
     || endswith(word,"au"))
       return "$(word)x"
    elseif (endswith(word,"ou"))
        return "$(word)s"
    elseif (endswith(word,"al"))
        return replace(word,r"al$" => "aux")
    elseif (endswith(word,"ail"))
        return "$(word)s"
    elseif (endswith(word,r"[abcdefghijklmnopqrtuvwy]"))
        return "$(word)s"
    else
        return word
    end
end
