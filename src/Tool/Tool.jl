function remove_id_from_name(str)

    if startswith(str,"id_")
         return str[4:length(str)]
    end
    if endswith(str,"_id")
         return str[1:length(str)-3]
    end

    return str

end

function build_module_name(str::String
                                  ;module_name_for_all_schemas::Union{String,Missing} = missing)
    if ismissing(module_name_for_all_schemas)
        return StringCases.classify(str)
    else
        return module_name_for_all_schemas
    end
end

function build_enum_module_name(str::String)
    StringCases.classify(str)
end

function build_enum_type_name(str::String)
    uppercase(StringCases.snakecase(str))
end

function build_enum_name_w_module(str::String)
    string(build_enum_module_name(str),
            ".",
            build_enum_type_name(str))
end

function build_enum_value(str::String)
    # StringCases.snakecase returns a lowercase string, we need to uppercase the result if
    # the original string was in uppercase.
    # NOTE: Base.Unicode.isuppercase returns false on non-letter characters
    StringCases.snakecase(str) |>
        n -> all(c -> !isletter(c) || Base.Unicode.isuppercase(c),str) ? uppercase(n) : n
end

function build_struct_name(str::String)
    StringCases.classify(str)
end

function build_struct_abstract_name(str::String)
    return "I$(build_struct_name(str))"
end

function build_field_name(str::String,
                                  lang_code::String
                                 ;replace_ids = false,
                                  is_onetomany = false)
    return build_field_name(tovector(str),
                                    lang_code::String
                                  ;replace_ids = replace_ids,
                                    is_onetomany = is_onetomany)
end

function build_field_name(str_arr::Vector{String},
                                  lang_code::String
                                 ;replace_ids = false,
                                  is_onetomany = false)

     if (replace_ids)
         str_arr = map(x -> remove_id_from_name(x),
                            str_arr)
     end

     field_name = join(str_arr, '_')
     field_name = StringCases.camelize(field_name)
     if is_onetomany
        field_name = PostgresORMUtil.pluralize(field_name,lang_code)
     end

     return field_name
end

function is_vector_of_enum(coltype::String,
                                     elttype::String,
                                     customtypes_names::Vector{String})
     if (coltype == "ARRAY")
          if elttype[2:end] in customtypes_names # remove the leading underscore
                return true
          end
     end
     return false
end

function is_vector_of_enum(coltype::String,
                                     elttype::String,
                                     customtypes::Dict)
     customtypes_names = keys(customtypes) |> collect |> n -> string.(n)
     return is_vector_of_enum(coltype,
                                        elttype,
                                        customtypes_names)
end

function get_fieldtype_from_coltype(
    coltype::String,
    elttype::String,
    customtypes::Dict,
    ;tablename::String = "",
    colname::String = ""
)

    if (colname == "duration")
        @info "duration coltype[$coltype]"
    end

    attrtype = missing
    customtypes_names = keys(customtypes) |> collect |> n -> string.(n)

    if (coltype == "character"
        || coltype == "character varying"
        || coltype == "text"
        || coltype == "uuid")
        attrtype = "String"
    elseif (coltype == "boolean")
        attrtype = "Bool"
    elseif (coltype == "smallint")
        attrtype = "Int16"
    elseif (coltype == "integer")
        attrtype = "Int32"
    elseif (coltype == "bigint")
        attrtype = "Int64"
    elseif (coltype == "numeric")
        attrtype = "Float64"
    elseif (coltype == "bytea")
        attrtype = "Vector{UInt8}"
    elseif (coltype == "date")
        attrtype = "Date"
    elseif (coltype == "time without time zone")
        attrtype = "Time"
    elseif (coltype == "timestamp without time zone")
        attrtype = "DateTime"
    elseif (coltype == "timestamp with time zone")
        attrtype = "ZonedDateTime"
    elseif coltype == "interval"
        attrtype = "Dates.CompoundPeriod"
    elseif (coltype == "ARRAY")
        if (elttype == "_text" || elttype == "_varchar")
          attrtype = "Vector{String}"
        elseif (elttype == "_numeric")
                attrtype = "Vector{Float64}"
        elseif (elttype == "_int4")
                attrtype = "Vector{Int64}"
        elseif is_vector_of_enum(coltype,elttype,customtypes_names)
          elttype = elttype[2:end] # remove the leading underscore
          attrtype = "Vector{$(build_enum_name_w_module(elttype))}"
        else
          error("Unknown array type[$elttype] for table[$tablename] column[$colname]")
        end
    elseif (coltype == "tsvector")
        attrtype = missing
    elseif (coltype == "bytea")
        attrtype = missing
    elseif (coltype == "USER-DEFINED")
        attrtype = build_enum_name_w_module(elttype)
    else
        error("Unknown type[$coltype] for table[$tablename] column[$colname]")
    end

    return attrtype
end

function generate_julia_code(
    dbconn::LibPQ.Connection,
    outdir::String
    ;lang_code = "eng",
    module_name_for_all_schemas::Union{String,Missing} = "Model",
    with_comment = true
)

    @info "BEGIN Julia code generation"
    object_model =
        generate_object_model(dbconn,
                              lang_code,
                              module_name_for_all_schemas = module_name_for_all_schemas)
    generate_structs_from_object_model(object_model, outdir; with_comment = with_comment)
    generate_orms_from_object_model(object_model, outdir)
    generate_enums_from_object_model(object_model, outdir)

    @info "ENDOF Julia code generation"

end


function generate_object_model(
    dbconn::LibPQ.Connection,
    lang_code::String
   ;ignored_columns::Vector{String} = Vector{String}(),
    camelcase_is_default::Bool = true,
    exceptions_to_default::Vector{String} = Vector{String}(),
    module_name_for_all_schemas::Union{String,Missing} = missing
)

    db_analysis = SchemaInfo.analyse_db_schema(dbconn)
    custom_types = SchemaInfo.get_custom_types(dbconn)

    # Initialize result as Dict
    object_model = Dict()

    # Initialize the various components of the result
    modules = []
    structs = []
    fields = []
    enums = []

    # Deal with the custom types
    for (k,v) in custom_types
        enum_name_w_module = build_enum_name_w_module(k)
        enum_values = []
        for val in v[:possible_values]
            enum_value = build_enum_value(val)
            push!(enum_values, enum_value)
        end
        push!(enums, Dict(:module_name => build_enum_module_name(k),
                                :type_name => build_enum_type_name(k),
                                :values => enum_values))
    end # ENDOF for (k,v) in custom_types

    # Deal with the schemas in ordre to fill in modules, structs and fields
    for (schema, schemadef) in db_analysis

        module_name = if ismissing(module_name_for_all_schemas)
                              build_module_name(schema
                                                     ;module_name_for_all_schemas = module_name_for_all_schemas)
                          else
                              module_name_for_all_schemas
                          end

        _module = Dict(:name => module_name,
                                             :schema => schema)
        push!(modules, _module)

        for (table,tabledef) in schemadef
            # Ignore table partitions (the partitioned table is the one of interest)
            if tabledef[:is_partition]
                continue
            end
            struct_name = build_struct_name(table)
            struct_abstract_name = build_struct_abstract_name(table)
            _struct = Dict(
                :name => struct_name,
                :module => _module,
                :abstract_name => struct_abstract_name,
                :table => table,
                :schema => schema,
                :comment => tabledef[:comment]
            )
            push!(structs, _struct)

            # Initialize some temporary arrays for the different types of fields
            struct_manytoone_fields = []
            struct_id_fields = []
            struct_basic_fields = []

            # Loop over the FKs of the table to add the complex field
            for (fkname,fkdef) in tabledef[:fks]
                manytoone_field = Dict()
                manytoone_field[:struct] = _struct
                manytoone_field[:referenced_table] = fkdef[:referenced_table]
                manytoone_field[:referenced_cols] = fkdef[:referenced_cols]
                manytoone_field[:cols] = fkdef[:referencing_cols]
                manytoone_field[:is_id] = false
                if occursin("onetoone",fkname) || occursin("one_to_one",fkname)
                    manytoone_field[:is_onetoone] = true
                    manytoone_field[:is_manytoone] = false
                else
                    manytoone_field[:is_onetoone] = false
                    manytoone_field[:is_manytoone] = true
                end
                manytoone_field[:is_onetomany] = false
                manytoone_field[:is_enum] = false
                manytoone_field[:is_vectorofenum] = false
                manytoone_field[:comment] = missing

                # Build a field name by one of the following options:
                # Case 1: The FK is composed of one column only. In this case we use
                #              the name of the column.
                # Case 2.1: The FK is composed of several columns and it is the only
                #                 FK in this table pointing to the given target table.
                #                 In this case we use the name of the target table.
                # case 2.2 The FK is composed of several columns and it there are
                #                 several FKs in this table pointing to the given target
                #                 table.  In this case we concatenate the referencing columns
                nb_fks_same_table_same_targeted_table = tabledef[:fks] |>
                    n -> filter(x -> x[2][:referenced_table] ==
                                            manytoone_field[:referenced_table],
                                    n) |> length
                manytoone_field[:name] = if length(manytoone_field[:cols]) == 1
                        build_field_name(manytoone_field[:cols],
                                              lang_code,
                                             ;replace_ids = true)
                    else
                        if nb_fks_same_table_same_targeted_table == 1
                            build_field_name(manytoone_field[:referenced_table][:table],
                                                  lang_code)
                        else
                            build_field_name(manytoone_field[:cols],
                                                  lang_code
                                                 ;replace_ids = true)
                        end
                    end

                # Build the referenced module.struct name
                # NOTE: We cannot get the information from 'structs' because the
                #            struct of interest is probably not available yet

                struct_name_w_module = (
                    build_module_name(manytoone_field[:referenced_table][:schema]
                      ;module_name_for_all_schemas = module_name_for_all_schemas)
                 * "."
                 * build_struct_name(manytoone_field[:referenced_table][:table])
                )

                struct_abstract_name_w_module = (
                    build_module_name(manytoone_field[:referenced_table][:schema]
                      ;module_name_for_all_schemas = module_name_for_all_schemas)
                 * "."
                 * build_struct_abstract_name(manytoone_field[:referenced_table][:table])
                )

                manytoone_field[:field_type] = struct_name_w_module
                manytoone_field[:field_abstract_type] = struct_abstract_name_w_module

                push!(struct_manytoone_fields, manytoone_field)

                # Check whether all the referencing columns are in the PK columns, if
                #    yes also add the property to the id property of the struct
                if all(map(x -> x in tabledef[:pk],
                              manytoone_field[:cols]))
                     manytoone_field[:is_id] = true
                end

            end # for (fkname,fkdef) in tabledef[:fks]

            # Store the referencing columns for control
            referencing_cols = []
            for v in (collect(values(tabledef[:fks])) |>
                         vect -> map(x -> x[:referencing_cols],vect))
              push!(referencing_cols,v...)
            end

            # Loop over the PKs of the table, if the PK is found in a FKs, skip
            #    because we already added it when looping over the FKs
            if tabledef[:pk] |> n -> map(x -> x ∈ referencing_cols, n) |> all
                @info "PK of table[$table] is contained in a FK"
            else

                for pkcol in tabledef[:pk]

                    id_field = Dict()
                    id_field[:struct] = _struct
                    id_field[:cols] = tovector(pkcol)
                    id_field[:is_id] = true
                    id_field[:is_manytoone] = false
                    id_field[:is_onetoone] = false
                    id_field[:is_onetomany] = false
                    id_field[:is_enum] = false
                    id_field[:is_vectorofenum] = false
                    field_name = build_field_name(pkcol,lang_code)
                    id_field[:name] = field_name
                    id_field[:comment] = missing

                    field_type =
                        get_fieldtype_from_coltype(tabledef[:cols][pkcol][:type],
                                                            tabledef[:cols][pkcol][:elttype_if_array],
                                                            custom_types)

                    # Check if it is an enum
                    if tabledef[:cols][pkcol][:type] == "USER-DEFINED"
                         id_field[:is_enum] = true
                    end

                    id_field[:field_type] = field_type
                    push!(struct_id_fields, id_field)

                end # ENDOF for pk in tabledef[:pk]

            end # ENDOF if tabledef[:pk] |> n -> map(x -> x ∈ referencing_cols, n) |> all



            # Loop over all the columns of the table and skip the ones that have
            #    already been mapped to complex properties or id properties
            for (colname, coldef) in tabledef[:cols]
                if colname in referencing_cols continue end
                if colname in tabledef[:pk] continue end

                basic_field = Dict()
                basic_field[:struct] = _struct
                basic_field[:cols] = tovector(colname)
                basic_field[:is_id] = false
                basic_field[:is_manytoone] = false
                basic_field[:is_onetoone] = false
                basic_field[:is_onetomany] = false
                basic_field[:is_enum] = false
                basic_field[:is_vectorofenum] = false
                field_name = build_field_name(colname,lang_code)
                basic_field[:name] = field_name
                basic_field[:comment] = coldef[:comment]

                field_type =
                    get_fieldtype_from_coltype(coldef[:type],
                                                        coldef[:elttype_if_array],
                                                        custom_types
                                                        ;tablename = table, colname = colname)

                # Check if it is an enum or a vector of enum
                if coldef[:type] == "USER-DEFINED"
                     basic_field[:is_enum] = true
                elseif is_vector_of_enum(coldef[:type], coldef[:elttype_if_array], custom_types)
                     basic_field[:is_vectorofenum] = true
                end

                basic_field[:field_type] = field_type
                push!(struct_basic_fields, basic_field)

            end

            # Enrich the arrays for all structs with this struct
            push!(fields, struct_manytoone_fields...)
            push!(fields, struct_id_fields...)
            push!(fields, struct_basic_fields...)

        end # ENDOF for (table,tabledef) in schemadef

    end # ENDOF for (schema, schemadef) in db_analysis


    # Now that we have all the struct known we can loop though the  manytoone
    #  fieds and build the corresponding onetomany fields.
    # Eg. For the manytoone (complex prop) 'Rental.staff' we build the onetomany
    #         'Staff.rentals of type Vector{IRental}'
    for manytoone_field in filter(x -> x[:is_manytoone] == true, fields)
        onetomany_field = Dict()
        onetomany_field[:is_id] = false
        onetomany_field[:is_manytoone] = false
        onetomany_field[:is_onetoone] = false
        onetomany_field[:is_onetomany] = true
        onetomany_field[:is_enum] = false
        onetomany_field[:is_vectorofenum] = false
        onetomany_type_name_w_module = manytoone_field[:field_type] # Public.Staff
        onetomany_field[:comment] = missing

        # Build a field_name using one of the following options:
        # Case1: The class holding the manytoone field has only one manytoone field
        #             pointing to the target class. In that case the name of the
        #             onetomany field in the target class will simply be the plural
        #             of the name of the manytoone field.
        #             Eg. Rental.staff -> rentals
        # Case2: There are several manytoone fields in the class pointing to the
        #             the same target class. In that case we concatenate the manytoone
        #             field name and the onetoname table name and we make it plural
        #             Eg. Sentence.judge => CivilServant.judgeSentences
        #                  Sentence.executionner => CivilServant.executionnerSentences
        #
        nb_manytoone_same_class_and_same_target_class = fields |>
              n -> filter(x -> (x[:struct][:name] == manytoone_field[:struct][:name]),n) |>
              n -> filter(x -> x[:is_manytoone],n) |>
              n -> filter(x -> x[:field_type] == manytoone_field[:field_type],n) |>
              length

        onetomany_field_name = if nb_manytoone_same_class_and_same_target_class == 1
                manytoone_field[:struct][:table]
            else
                string(manytoone_field[:name],"_",manytoone_field[:struct][:table])
            end
        onetomany_field_name = build_field_name(onetomany_field_name,
                                                             lang_code
                                                            ;is_onetomany = true)
        onetomany_field_type =
          "Vector{$(manytoone_field[:struct][:module][:name]).$(manytoone_field[:struct][:name])}"
        onetomany_field_abstract_type =
            "Vector{$(manytoone_field[:struct][:module][:name]).$(manytoone_field[:struct][:abstract_name])}"

        onetomany_field[:name] = onetomany_field_name
        onetomany_field[:field_type] = onetomany_field_type
        onetomany_field[:field_abstract_type] = onetomany_field_abstract_type
        onetomany_field[:manytoone_field] = manytoone_field

        # Loop over the structs to link it to the
        for _struct in structs
            if "$(_struct[:module][:name]).$(_struct[:name])" == onetomany_type_name_w_module
                onetomany_field[:struct] = _struct
            end
        end
        if !haskey(onetomany_field,:struct)
            error("Unable to find a struct $onetomany_type_name_w_module")
        end

        # Add the fields to the other fields
        # NOTE: There is no risk to creaet an infinite loop because we loop over
        #              the filtered array and not the array itself
        push!(fields,onetomany_field)
    end


    return Dict(
       :modules => modules,
       :structs => structs,
       :fields => fields,
       :enums => enums
    )

end

function generate_enums_from_object_model(object_model::Dict, outdir::String)

    outdir = joinpath(outdir,"enum")
    enums = object_model[:enums]

    result = ""
    for e in enums
        result *= "module $(e[:module_name])\n"
        result *= "  export $(e[:type_name])\n"
        result *= "  @enum $(e[:type_name]) begin\n"

        counter = 0
        for v in e[:values]
            counter += 1
            result *= "     $v = $counter \n"
        end

        result *= "  end\n" # close type
        result *= "end\n\n" # close module
    end

    if !isdir(outdir)
        mkpath(outdir)
    end
    # @info file_path
    file_path = joinpath(outdir,"enums.jl")
    write(file_path,result)

end

function add_comment_before_of_after(str::String, comment::String)
   if length(str) + length(comment) + 3 > 92
      result = insert_newlines_preserving_words(comment, "  # ")
      result *= "\n"
      result *= "$str"
      result = "\n$result\n" # Add some additional line returns for better readability
   else
      result = "$str # $comment"
   end
   return result
end

function insert_newlines_preserving_words(s::String, prefix::String; n::Int=92)
   # Split the string into words
   words = split(s)

   # Initialize an empty string to build the result
   result = ""

   # Initialize a line buffer and a character counter
   line = ""
   char_count = 0

   for word in words
       # Check if adding the next word exceeds the limit
       if char_count + length(word) + (char_count > 0 ? 1 : 0) > n
           # Add the current line with prefix to the result and reset it
           result *= prefix * line * "\n"
           line = word  # Start a new line with the current word
           char_count = length(word)
       else
           # Add the word to the current line
           line *= (char_count > 0 ? " " : "") * word
           char_count += length(word) + (char_count > 0 ? 1 : 0)  # +1 for the space if not the first word
       end
   end

   # Add the last line with prefix to the result
   if !isempty(line)
       result *= prefix * line
   end

   return result
end

function generate_structs_from_object_model(
    object_model::Dict,
    outdir::String
    ;with_comment::Bool = true
)

    outdir = joinpath(outdir,"structs")

    modules = object_model[:modules]
    structs = object_model[:structs]
    fields = object_model[:fields]

    indent = " "

    # Reset content
    for _struct in structs
        _struct[:struct_content] = ""
    end

    # ############################################ #
    # Add table comment as docstring of the struct #
    # ############################################ #
    if with_comment
      for _struct in structs
         if !ismissing(_struct[:comment])
               str = "\"\"\"\n"
               str *= "$(_struct[:comment])\n"
               str *= "\"\"\"\n"
               _struct[:struct_content] *= str
         end
      end
    end

    # ################ #
    # Open the struct #
    # ################ #
    for _struct in structs
        str = "mutable struct $(_struct[:name]) <: $(_struct[:abstract_name]) \n\n"
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
        field_type = if (f[:is_manytoone] || f[:is_onetoone] || f[:is_onetomany])
            f[:field_abstract_type]
        else
            f[:field_type]
        end
        str = "  $field_name::Union{Missing,$field_type}"
        length_of_field_definition = length(str)
        if :comment ∉ keys(f)
          @warn "Missing comment key for field[$(f[:name])] $(f[:is_onetomany]), $(f[:is_manytoone]), $(f[:is_onetoone])"
        else
          if with_comment && !ismissing(f[:comment])
            str = add_comment_before_of_after(str,f[:comment])
          end
        end
        str *= "\n"
        _struct[:struct_content] *= str
    end

    # ############################ #
    # Create the first constructor #
    # ############################ #
    for _struct in structs
        str = "\n"
        str *= "  $(_struct[:name])(args::NamedTuple) = $(_struct[:name])(;args...)"
        _struct[:struct_content] *= str
    end

    # ########################### #
    # Open the second constructor #
    # ########################### #
    for _struct in structs
        str = "\n"
        str *= "  $(_struct[:name])(;\n"
        _struct[:struct_content] *= str
    end

    # ####################################################### #
    # Add the arguments declaration of the second constructor #
    # ####################################################### #
    for f in fields

        _struct = f[:struct]

        field_name = f[:name]
        str = "    $field_name = missing,\n"
        _struct[:struct_content] *= str
    end

    # ######################################################### #
    # Close the arguments declaration of the second constructor #
    # ######################################################### #
    for _struct in structs
        str = ""
        str *= "  ) = begin\n"
        str *= "    x = new("
        _struct[:struct_content] *= str
    end

    # #################################################################################### #
    # Add the 'new(missing, missing, ...)' arguments assignment of the second constructor #
    # #################################################################################### #
    for f in fields

        _struct = f[:struct]

        str = "missing,"
        _struct[:struct_content] *= str
    end

    # ############################################################ #
    # Close 'new(missing, missing, ...)' of the second constructor #
    # ############################################################ #
    for _struct in structs
        str = ")\n"
        _struct[:struct_content] *= str
    end

    # ###################################################### #
    # Add the arguments assignment of the second constructor #
    # ###################################################### #
    for f in fields

        _struct = f[:struct]

        str = "    x.$(f[:name]) = $(f[:name])\n"
        _struct[:struct_content] *= str
    end

    # ######################################################## #
    # Close the arguments assignment of the second constructor #
    # ######################################################## #
    for _struct in structs
        str = "    return x\n"
        str *= "  end\n"
        _struct[:struct_content] *= str
    end

    # ################ #
    # Close the struct #
    # ################ #
    for _struct in structs
        str = "\nend "
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

    # Write abstract types
    for _struct in structs
        str = "abstract type $(_struct[:abstract_name]) <: IEntity end\n"
        module_dir = joinpath(outdir,_struct[:module][:name])
        file_path = joinpath(module_dir,"abstract-types.jl")
        io = open(file_path, "a");
        write(io,str)
        close(io);
    end

    # Write the content of structs to files
    for _struct in structs
        module_dir = joinpath(outdir,_struct[:module][:name])
        if !isdir(module_dir)
            mkpath(module_dir)
        end
        file_path = joinpath(module_dir,"$(_struct[:name]).jl")

        # Cleaning of too many line returns (this can happen when adding a field comment)
        _struct[:struct_content] = replace(_struct[:struct_content], "\n\n\n\n" => "\n\n")
        _struct[:struct_content] = replace(_struct[:struct_content], "\n\n\n" => "\n\n")

        write(file_path,_struct[:struct_content])
    end

end

function generate_orms_from_object_model(object_model::Dict, outdir::String)

    outdir = joinpath(outdir,"orms")

    modules = object_model[:modules]
    structs = object_model[:structs]
    fields = object_model[:fields]

    # Check how may different modules we have, if only one, there is no need
    #    to put the ORMs' modules in separate submodules of the ORM root module
    #    (i.e. we don't need a module ORM.Public, ORM.SchmeName1, ...)
    nb_different_modules = length(unique(x -> x[:name],modules))

    orm_root_module = "ORM"

    indent = " "

    # ####################################### #
    # Data type, ORM, schema name, table name #
    # ####################################### #

    for _struct in object_model[:structs]

        struct_name = "$(_struct[:module][:name]).$(_struct[:name])"
        orm_name = if nb_different_modules > 1
                "$(orm_root_module).$(_struct[:module][:name]).$(_struct[:name])ORM"
            else
                "$(orm_root_module).$(_struct[:name])ORM"
            end

        table = _struct[:table]
        schema = _struct[:schema]

        orm_content = ("
data_type = $struct_name
PostgresORM.get_orm(x::$struct_name) = return($(orm_name))
get_schema_name() = \"$schema\"
get_table_name() = \"$table\"
")

        _struct[:orm_content] = orm_content
        _struct[:orm_name] = orm_name

    # write(filename_for_orm_module,orm_content)

    end #ENDOF `for _struct in structs`


    # ############################# #
    # Columns selection and mapping #
    # ############################# #

    # Declare the function and open the Dict
    for _struct in object_model[:structs]
        str = "\n\n"
        str *= "# Declare the mapping between the properties and the database columns\n"
        str *= "get_columns_selection_and_mapping() = return columns_selection_and_mapping"
        str *= "\nconst columns_selection_and_mapping = Dict(\n"
        _struct[:orm_content] *= str
    end #ENDOF `for _struct in structs`


    mapping_arr = []
    for f in fields

        # Skip the onetomany fields because they do not have any correson column
        if f[:is_onetomany] continue end

        field_name = f[:name]
        # colnames =  "[$(join(f[:cols],", "))]"

        colnames =  if length(f[:cols]) > 1
                            "[" * join( string.("\"", f[:cols], "\""), ", ") * "]"
                        else
                            "\"$(f[:cols][1])\""
                        end
        # colnames = "r4r4W"
        str = "$(repeat(indent,1)) :$(field_name) => $colnames, \n"
        f[:struct][:orm_content] *= str

    end # ENDOF `for id_field in object_model[:id_fields]`

    # Close the Dict for 'columns_selection_and_mapping'
    for _struct in object_model[:structs]
        _struct[:orm_content] *= ")\n\n"
    end


    # ############# #
    # ID properties #
    # ############# #

    # Open the function
    for _struct in object_model[:structs]
        _struct[:orm_content] *= "\n"
        _struct[:orm_content] *= "# Declare which properties are used to uniquely identify an object\n"
        _struct[:orm_content] *= "get_id_props() = return ["
    end

    # Add the fieds
    for f in filter(x -> x[:is_id], fields)
        f[:struct][:orm_content] *= ":$(f[:name]),"
    end

    # Close the function
    for _struct in object_model[:structs]
        _struct[:orm_content] *= "]"
    end

    # ###################### #
    # onetomany_counterparts #
    # ###################### #
    # Declare the function and open the Dict
    for _struct in object_model[:structs]
        _struct[:orm_content] *= "\n\n"
        _struct[:orm_content] *= "# Associate the onetomany properties to the corresponding manytoone peroperties in the other classes \n"
        _struct[:orm_content] *= "get_onetomany_counterparts() = return onetomany_counterparts\n"
        _struct[:orm_content] *= "const onetomany_counterparts = Dict(\n"
    end

    # Add the fieds
    for f in filter(x -> x[:is_onetomany], fields)

        field_name = f[:name]
        field_type = f[:field_type]
        manytoone = f[:manytoone_field]
        manytoone_struct =
            "$(manytoone[:struct][:module][:name]).$(manytoone[:struct][:name])"
        manytoone_field_name = manytoone[:name]

        tip_for_data_type = "# The struct where the associated manytoone property is"
        tip_for_property = "# The name of the associated manytoone property"
        tip_for_action_on_remove =
            "# Change this to 'PostgresORM.CRUDType.delete' if the object doesn't make sense when orphaned"

        str = "
  :$(field_name) => (
    data_type = $manytoone_struct, $tip_for_data_type
    property = :$manytoone_field_name, $tip_for_property
    action_on_remove = PostgresORM.CRUDType.update), $tip_for_action_on_remove \n"

      f[:struct][:orm_content] *= str
    end

    # Close the Dict
    for _struct in object_model[:structs]
        _struct[:orm_content] *= "\n)"
    end


    # ############## #
    # Types override #
    # ############## #
    # Declare the function and open the Dict
    for _struct in object_model[:structs]
        _struct[:orm_content] *= "\n\n"
        _struct[:orm_content] *= "# Override the abstract types \n"
        _struct[:orm_content] *= "get_types_override() = return types_override\n"
        _struct[:orm_content] *= "const types_override = Dict(\n"
    end

    # Add the fieds for the manytoone and onetomany fields
    for f in filter(x -> (x[:is_manytoone] || x[:is_onetoone] || x[:is_onetomany]),
                                fields)
        field_name = f[:name]
        field_type = f[:field_type]
        str = "$(repeat(indent,1)) :$(field_name) => $field_type, \n"
        f[:struct][:orm_content] *= str
    end

    # Close the Dict
    for _struct in object_model[:structs]
        _struct[:orm_content] *= "\n)"
    end


    # ############# #
    # Track changes #
    # ############# #
    # Declare the function and open the Dict
    for _struct in object_model[:structs]
        _struct[:orm_content] *= "\n\n"
        _struct[:orm_content] *= "# Specify whether we want to track the changes to the objects of this class \n"
        _struct[:orm_content] *= "# get_track_changes() = false # Uncomment and modify if needed \n"
        _struct[:orm_content] *= "# get_creator_property() = :a_property_symbol # Uncomment and modify if needed \n"
        _struct[:orm_content] *= "# get_editor_property() = :a_property_symbol # Uncomment and modify if needed \n"
        _struct[:orm_content] *= "# get_creation_time_property() = :a_property_symbol # Uncomment and modify if needed \n"
        _struct[:orm_content] *= "# get_update_time_property() = :a_property_symbol # Uncomment and modify if needed \n"
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

    # Write abstract types
    for _struct in structs
        module_dir = joinpath(outdir,_struct[:module][:name])
        orm_name_wo_module =
            _struct[:orm_name][
                findlast(".",_struct[:orm_name])[1]+1:length(_struct[:orm_name])
                ]
        file_path = joinpath(module_dir,"$orm_name_wo_module.jl")
        io = open(file_path, "w");
        write(io,_struct[:orm_content])
        close(io);
    end

    return object_model

end
