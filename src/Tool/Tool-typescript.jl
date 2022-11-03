function generate_typescript_code(dbconn::LibPQ.Connection,
                                  outdir::String,
                                  relative_path_to_enum_dir::String
                                  ;lang_code = "eng",
                                  module_name_for_all_schemas::Union{String,Missing} = "Model")

    object_model = generate_object_model(
        dbconn,
        lang_code,
        module_name_for_all_schemas = module_name_for_all_schemas
    )

    generate_typescript_enums_from_object_model(object_model, outdir)

    generate_typescript_classes_from_object_model(object_model,
                                                  outdir,
                                                  relative_path_to_enum_dir)

end


function generate_typescript_enums_from_object_model(object_model::Dict, outdir::String)

    outdir = joinpath(outdir,"enum")

    if !isdir(outdir)
        mkpath(outdir)
     end

    enums = object_model[:enums]

    for e in enums

       type_name = e[:type_name]
       file_path = joinpath(outdir,"$type_name.ts")

       content = "export enum $type_name {\n\n"

       for (idx,v) in enumerate(e[:values])
          content *= "    $v = $idx, \n"
       end

       content *= "\n"
       content *= "}" # close enum

       write(file_path,content)
    end



end

"""
    get_typescript_type_of_elt_type(julia_elt_type::String)

Eg. Model.Patient returns Patient
"""
 function get_typescript_type_of_elt_type(julia_elt_type::String)

    julia_elt_type = (last ∘ split)(julia_elt_type,".")

    typescript_elt_type = try
        basic_elt_type = eval(Symbol(julia_elt_type))
        if basic_elt_type == Bool
            typescript_elt_type = "boolean"
        elseif basic_elt_type == String
                typescript_elt_type = "string"
        elseif (basic_elt_type <: Date
            || basic_elt_type <: DateTime
            || basic_elt_type <: ZonedDateTime)
            typescript_elt_type = "Date"
        elseif basic_elt_type <: Number
            typescript_elt_type = "number"
        end
    catch e
        typescript_elt_type = julia_elt_type
    end
    return typescript_elt_type
end

"""
    get_typescript_elt_type(_field::Dict)

Eg. Vector{Model.Patient} returns Patient
"""
function get_typescript_elt_type(_field::Dict)
    chop(get_typescript_type(_field), tail = 2) # Remove the trailing '[]'
end

"""
    get_typescript_type(_field::Dict)

Eg. Vector{Model.Patient} returns Patient[]
"""
function get_typescript_type(_field::Dict)

    _regexVector = r"Vector{([a-zA-Z0-9._]+)}"

    if (_m = match(_regexVector, _field[:field_type])) |> !isnothing
        elt_type_name = _m |>
            n -> string(n.captures[1])
            typescript_elt_type = get_typescript_type_of_elt_type(elt_type_name)
        return "$typescript_elt_type[]"
    else
        return get_typescript_type_of_elt_type(_field[:field_type])
    end

end


 function generate_typescript_classes_from_object_model(object_model::Dict,
                                                        outdir::String,
                                                        relative_path_to_enum_dir::String)

    outdir = joinpath(outdir,"classes")

    modules = object_model[:modules]
    structs = object_model[:structs]
    fields = object_model[:fields]

    # Reset content
    for _struct in structs
       _struct[:struct_content] = ""
    end

    # ################ #
    # Open the struct #
    # ################ #
    for _struct in structs
       str = "export class $(_struct[:name]) {\n\n"
       _struct[:struct_content] *= str
    end

    # ################## #
    # Declare the fields #
    # ################## #
    for f in fields

       if !haskey(f,:struct)
          @error f
          return
       end

       _struct = f[:struct]

       field_name = f[:name]
       typescript_type = get_typescript_type(f)
       str = "    $field_name:$typescript_type;\n"
       _struct[:struct_content] *= str
    end

    # #################### #
    # Open the constructor #
    # #################### #
    for _struct in structs
       str = "\n"
       str *= "    constructor(_json:Object) {\n"
       _struct[:struct_content] *= str
    end

    # ####################################################### #
    # Add the arguments declaration of the second constructor #
    # ####################################################### #
    for f in fields

        _struct = f[:struct]

        field_name = f[:name]
        indent = repeat(" ", 8)
        str = ""
        if (f[:is_onetoone] || f[:is_manytoone])
            str *= indent * "if (_json['$field_name'] != null) {\n"
            str *= indent * "    " * "this.$field_name = new $(get_typescript_type_of_elt_type(f[:field_type]))(_json['$field_name']);\n"
            str *= indent * "}\n"
        elseif f[:is_onetomany]
            elt_type = get_typescript_elt_type(f)
            str *= indent * "if (_json['$field_name'] != null) {\n"
            str *= indent * "    " * "this.$field_name = [];\n"
            str *= indent * "    " * "for (let e of _json['$field_name']) {\n"
            str *= indent * "        " * "this.$field_name.push(new $elt_type(e));\n"
            str *= indent * "    " * "}\n"
            str *= indent * "}\n"
        elseif f[:is_enum]
            str *= indent * "if (_json['$field_name'] != null) {\n"
            str *= indent * "    " * "if (isNaN(Number(_json['$field_name']))) {\n"
            str *= indent * "    " * "    " * "this.$field_name = Number($(get_typescript_type_of_elt_type(f[:field_type]))[_json['$field_name']]);\n"
            str *= indent * "    " * "} else {\n"
            str *= indent * "    " * "    " * "this.$field_name = Number(_json['$field_name']);\n"
            str *= indent * "    " * "}\n"
            str *= indent * "}\n"
        elseif f[:is_vectorofenum]
            elt_type = get_typescript_elt_type(f)
            str *= indent * "if (_json['$field_name'] != null) {\n"
            str *= indent * "    " * "this.$field_name = [];\n"
            str *= indent * "    " * "for (let e of _json['$field_name']) {\n"
            str *= indent * "    " * "    " * "if (isNaN(Number(e))) {\n"
            str *= indent * "    " * "    " * "    " * "this.$field_name.push(Number($elt_type[e]));\n"
            str *= indent * "    " * "    " * "} else {\n"
            str *= indent * "    " * "    " * "    " * "this.$field_name.push(Number(e));\n"
            str *= indent * "    " * "    " * "}\n"
            str *= indent * "    " * "}\n"
            str *= indent * "}\n"
        elseif get_typescript_type(f) == "Date"
            str *= indent * "if (_json['$field_name'] != null) {\n"
            str *= indent * "    " * "this.$field_name = new Date(_json['$field_name']);\n"
            str *= indent * "}\n"
        else
            str *= indent * "this.$field_name = _json['$field_name'];\n"
        end
           _struct[:struct_content] *= str
    end

    # ############################ #
    # Close the constructor #
    # ############################ #
    for _struct in structs
       str = "    }\n"
       _struct[:struct_content] *= str
    end

    # ################################################# #
    # Initialize the vector of imports for every struct #
    # ################################################# #
    for _struct in structs
        _struct[:imports] = []
    end

    # ######################################################## #
    # Add the imports for enums, vetors of enum, complex types #
    # ######################################################## #
    for f in fields

        _struct = f[:struct]
        if (f[:is_onetoone] || f[:is_manytoone])
            elt_type = get_typescript_type_of_elt_type(f[:field_type])
            pathToImport = joinpath("./",elt_type)
            push!(
                _struct[:imports],
                 "import { $elt_type } from \"$pathToImport\""
            )
        elseif f[:is_onetomany]
            elt_type = get_typescript_elt_type(f)
            pathToImport = joinpath("./",elt_type)
            push!(
                _struct[:imports],
                 "import { $elt_type } from \"$pathToImport\""
            )
        elseif f[:is_enum]
            elt_type = get_typescript_type_of_elt_type(f[:field_type])
            pathToImport = joinpath(relative_path_to_enum_dir,elt_type)
            push!(
                _struct[:imports],
                "import { $elt_type } from \"$pathToImport\""
            )
        elseif f[:is_vectorofenum]
            elt_type = get_typescript_elt_type(f)
            pathToImport = joinpath(relative_path_to_enum_dir,elt_type)
            push!(
                _struct[:imports],
                "import { $elt_type } from \"$pathToImport\""
            )
        end

    end
    # Add the string of imports
    for _struct in structs
        if length(_struct[:imports]) > 0
            stringOfImports = join(unique(_struct[:imports]),";\n") * ";\n\n"
            _struct[:struct_content] = stringOfImports * _struct[:struct_content]
        end
    end

    # ################ #
    # Close the struct #
    # ################ #
    for _struct in structs
       str = "\n} "
       _struct[:struct_content] *= str
    end

    # ############## #
    # Write to files #
    # ############## #

    # Empty the modules dirs
    for _module in modules
       module_dir = joinpath(outdir,_module[:name])
       rm(module_dir, recursive=true, force = true)
       mkpath(module_dir)
    end


    # Write the content of structs to files
    for _struct in structs
       module_dir = joinpath(outdir,_struct[:module][:name])
       if !isdir(module_dir)
          mkpath(module_dir)
       end
       file_path = joinpath(module_dir,"$(_struct[:name]).ts")
       write(file_path,_struct[:struct_content])
    end

 end
