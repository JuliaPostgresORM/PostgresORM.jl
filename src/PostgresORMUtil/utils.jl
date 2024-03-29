using LibPQ
# using Query
using JSON

function getproperties_asdict(object::Any,include_missing::Bool)
    properties_symbols = propertynames(object) # Get the properties as a vector of Symbol
    props::Dict{Symbol,Any} =
        Dict(zip(properties_symbols, # The properties symbols
        getfield.([object],properties_symbols)) # the properties values
                    )
    # Remove the missing properties if needed
    if (!include_missing)
        props_as_vectoroftuples = dict2vectoroftuples(props)
        props_as_vectoroftuples_womissing = filter(t -> !ismissing(t[2]),
                                                   props_as_vectoroftuples)
        props = vectoroftuples2dict(props_as_vectoroftuples_womissing)
    end
    return props

end

function getpropertiesvalues(obj::Any,props::Vector{Symbol})
    values = []
    for p in props
        push!(values,getproperty(obj,p))
    end
    return values
end

function getdictvalues(dict::Dict,props::Vector{Symbol})
    # NOTE: Cannot use the following line because we want the values in the same
    #           order as the props argument
    # collect(values(filter(x -> x.first in props, dict)))

    values = []
    for p in props
        push!(values,get(dict,p,missing))

    end
    return values
end

function getdictvalues(dict::Dict,props::Vector{String})
    # NOTE: Cannot use the following line because we want the values in the same
    #           order as the props argument
    # collect(values(filter(x -> x.first in props, dict)))

    values = []
    for p in props
        push!(values,get(dict,p,missing))

    end
    return values
end

function setpropertiesvalues!(obj::Any,props::Vector{Symbol},values::Vector)
    for (p,v) in zip(props,values)
        setproperty!(obj,p,v)
    end
end

function dataframe2vector_of_namedtuples(df::DataFrame)
    result = []
    for row in eachrow(df)
        push!(result, dataframerow2namedtuple(row))
    end
    return result
end

function dataframerow2namedtuple(row::DataFrameRow)
    vals = values(row)
    cols = Symbol.(names(row))
    dict2namedtuple(Dict(zip(cols,vals)))
end

function vectoroftuples2dict(t::Vector{Tuple{T,K}}) where {T <: Any, K <: Any}
    Dict(zip(
            first.(t), # keys
            last.(t) # values
            )
        )
end

function dict2vectoroftuples(d::Dict)
    collect(zip(collect(keys(d)),collect(values(d))))
end

# https://discourse.julialang.org/t/how-to-make-a-named-tuple-from-a-dictionary/10899/10?u=tencnivel
function dict2namedtuple(d::Dict)
    (; d...)
end

dictstringkeys2symbol_helper(x) = x
dictstringkeys2symbol_helper(d::Array) = dictstringkeys2symbol_helper.(d)
dictstringkeys2symbol_helper(d::Dict) =
    Dict(Symbol(k) => dictstringkeys2symbol_helper(v) for (k, v) in d)
function dictstringkeys2symbol(d::Dict)
    dictstringkeys2symbol_helper(d)
end

dictnothingvalues2missing_helper(x) = x
dictnothingvalues2missing_helper(x::Nothing) = missing
dictnothingvalues2missing_helper(d::Array) = dictnothingvalues2missing_helper.(d)
dictnothingvalues2missing_helper(d::Dict) =
    Dict(k => dictnothingvalues2missing_helper(v) for (k, v) in d)
function dictnothingvalues2missing(d::Dict)
    dictnothingvalues2missing_helper(d)
end

# https://discourse.julialang.org/t/how-to-make-a-named-tuple-from-a-dictionary/10899/11?u=tencnivel
function namedtuple2dict(nt::NamedTuple)
    Dict{Symbol,Any}(pairs(nt))
end

function string2enum(enumType::DataType,str::SubString{String})
    string2enum(enumType,string(str))
end

function string2enum(enumType::DataType,str::String)
    if ismissing(str)
        return missing
    end

    result = try
        enum_ints = Int.(instances(enumType))
        enum_names = string.(instances(enumType))

        index_oi = findfirst(x -> x == str,enum_names)

        enum_int = enum_ints[index_oi]
        enumType(enum_int)
    catch e
        throw(DomainError("Unable to convert[$str] to Enum[$enumType]"))
    end

    return result

end

"""
"""
function string2vector_of_enums(vectorOfEnumsTypes::Type{Vector{T}},
                                str::Union{String,Missing}) where T <: Base.Enums.Enum
    enumType = eltype(vectorOfEnumsTypes)

    if ismissing(str)
        return missing
    end

    # If no element in the array return an empty array
    if str == "{}"
        return T[]
    end

    chop(str,head = 1,tail = 1) |> n -> split(n,",") |>
        n -> string.(n) |>
        n -> string2enum.(enumType,n)

end

function vector_of_strings2vector_of_enums(
    vectorOfEnumsTypes::Type{Vector{T}} where T <: Base.Enums.Enum,
    vectorOfInts::Union{Vector{String},Vector{Union{String,Missing}}})

    enumType = eltype(vectorOfEnumsTypes)

    return string2enum.(enumType,vectorOfInts)

end

function vector_of_integers2vector_of_enums(
    vectorOfEnumsTypes::Type{Vector{T}} where T <: Base.Enums.Enum,
    vectorOfInts::Union{Vector{W},Vector{Union{W,Missing}}} where W <: Integer)

    enumType = eltype(vectorOfEnumsTypes)

    return int2enum.(enumType,vectorOfInts)

end

function string2zoneddatetime(str)

    # Attempt 1: eg. "2019-09-03T11:00:00.000Z"
    date_match_GMT =
        match(r"^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3}Z)$", str)
    if !isnothing(date_match_GMT)
        # "2019-07-24T00:41:49.732Z" becomes "2019-07-24T00:41:49.732"
        date_match_remove_endingZ =
          match(r"^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3})",
                str)
        utc_zdt =
            ZonedDateTime(DateTime(date_match_remove_endingZ.match),
                          TimeZone("UTC"))
        return utc_zdt
    end

    # Attempt 2: eg. "2022-04-09T18:06:26+02:00"
    date_match_with_tz1 =
        match(r"^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\+[0-9]{2}:[0-9]{2})$", str)
    if !isnothing(date_match_with_tz1)
        zdt =
            ZonedDateTime(date_match_with_tz1.match,"yyyy-mm-ddTHH:MM:SSzzzz")
        return zdt
    end

    # Attempt 3: eg. "2022-04-08T02:30:22.668+02:00"
    date_match_with_tz1 =
        match(r"^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3}\+[0-9]{2}:[0-9]{2})$", str)
    if !isnothing(date_match_with_tz1)
        zdt =
            ZonedDateTime(date_match_with_tz1.match,"yyyy-mm-ddTHH:MM:SS.ssszzzz")
        return zdt
    end

    return nothing

end

function int2enum(enumType::DataType,enum_int::Missing)
    return missing
end

function int2enum(enumType::DataType,enum_int::Integer)
    enumType(enum_int)
end

function enum2int(enumobject::T) where T <: Enum
    Int(enumobject)
end

function tovector(x;elementstype = missing)

    # Create vector
    if isa(x,Vector)
        result = x
    elseif isa(x,Tuple)
        result = collect(x)
    elseif isa(x,Number) || isa(x,String) || isa(x,Bool) || isa(x,Symbol)
        result = [x]
    else
        throw(ArgumentError("Unsupported type[$(typeof(x))]"))
    end

    # Convert vector
    if (!ismissing(elementstype))
        if elementstype == Symbol
            result = Symbol.(result)
        elseif elementstype == String
            result = string.(result)
        else
            throw(ArgumentError("Unsupported elementstype[$elementstype]"))
        end
    end

    return result

end



"""
    postgresql_string_array_2_string_vector(str::String)

Transform the following string "{"Deleted,. 3, Scenes a2e","Behind the Scenes",""}"
(that's what we get from postrgesql) into a string vector fo size 3
"""
function postgresql_string_array_2_string_vector(str::String)

    #TODO handle the case "{\"bla bla\",bb,cc}"

    if occursin("\"",str)

        my_matches =
            #              1            2          3          4           5
            eachmatch(r"(?:\"([^\"]*)\"|,([^\"]*),|{([^\"]*),|{([^\"]*)}|,([^\"]*)})",
            # Where 1: "Deleted,. 3, Scenes a2e" => Deleted,. 3, Scenes a2e
            #       2: ,dwed, => dwed
            #       3: {dwed, => dwed
            #       4: {dwed} => dwed
            #       5: ,dwed} => dwed
                       str
                      )
        return map(m ->filter(x -> !isnothing(x), m.captures) |> n -> (string ∘ first)(n),
            collect(my_matches))
      else
          return  str[2:length(str)-1] |>
                   n -> split(n,",") |>
                   n -> string.(n)
      end


end

# This method exists so that we can call it even without having to test if the
#   argument is a Union
function get_nonmissing_typeof_uniontype(arg::Any)
    return arg
end

# NOTE: We cannot say that this method returns a DataType (::DataType) because
#         arrays are not datatypes
function get_nonmissing_typeof_uniontype(arg::Union)
    if arg.a != Missing && arg.a != Nothing
        return get_nonmissing_typeof_uniontype(arg.a)
    else
        return get_nonmissing_typeof_uniontype(arg.b)
    end
end


function diff_dict(old_dict::Dict, new_dict::Dict)

    old_dict_keys = collect(keys(old_dict))
    new_dict_keys = collect(keys(new_dict))

    diff_result = Dict()

    # Loop over the old dictionary keys
    for (k,v) in old_dict
        # Values that have changed without being nulled
        if k in new_dict_keys

            # Dirty quickfix to handle byte arrays
            if isa(v,Vector{UInt8})
                diff_result[k] = (old = "old bytea", new = "new bytea")
                continue
            end

            # For vectors of things that are not IEntity it is possible that
            #   we have a missing value although the property has been loaded
            if ((isa(v, Vector) && !isa(v,Vector{<:PostgresORM.IEntity}))
             || (isa(new_dict[k], Vector) && !isa(new_dict[k],Vector{<:PostgresORM.IEntity})))
                if old_dict[k] !== new_dict[k]
                    diff_result[k] = (old = old_dict[k], new = new_dict[k])
                end
                continue
            end

            # Sanity check, we do not allow comparing a vector with missing
            #   because it's a symptom of the user not comparing objects that
            #   can be compared. Recall that when we load a vector property from
            #   the database, it will be at least an empty array never missing.
            if (isa(v, Vector) && ismissing(new_dict[k]))
                throw(DomainError(
                    "You are trying to compare Missing with a Vector for "
                    *"property[$k]. Missing property is in the new version."))
            end
            if (isa(new_dict[k], Vector) && ismissing(v))
                throw(DomainError(
                    "You are trying to compare Missing with a Vector for "
                    *"property[$k]. Missing property is in the old version."))
            end

            if (ismissing(old_dict[k]) && ismissing(new_dict[k]))
                # do nothing
            elseif (ismissing(old_dict[k]) && !ismissing(new_dict[k])) ||
               (!ismissing(old_dict[k]) && ismissing(new_dict[k])) ||
               old_dict[k] != new_dict[k]
               diff_result[k] = (old = old_dict[k], new = new_dict[k])
            end
        # Values that have been nulled
        elseif  !(k in new_dict_keys)
            diff_result[k] = (old = old_dict[k], new = missing)
        end
    end

    # Loop over the new dictionary for new keys
    for k in new_dict_keys
        if !(k in old_dict_keys)
            diff_result[k] = (old = missing, new = new_dict[k])
        end
    end

    diff_result

end


function remove_spaces_and_split(str::String)
    str = replace(str, " " => "")
    return split(str,',')
end

"""
    dedup_colnames_colvalues!(column_names::Vector{String}, column_values::Vector)

Inplace dedup column names and values by giving priority to non missing elements

Eg.
Applying function to the following arguments:
column_names = ["exam_log_id", "in_date", "in_date", "out_time", "api_url", "in_time", "user_id"]
column_values = ["215c81e9-e002-402e-8482-1382a65ef1e4", "2024-03-11", missing, "2024-03-11T08:27:12.363+01:00", "exam/save-values", "2024-03-11T08:27:09.363+01:00", "b7845f35-0169-488d-b8ce-111f0f07d695"]

will result in a dropping the third element of both vectors

"""
function dedup_colnames_colvalues!(
    column_names::Vector{String},
    column_values::Vector
)

    # Function to check if a value is considered "missing" in your context
    is_missing(value) = value === missing  # Replace 'nothing' with your definition of a missing value

    # Create a dictionary to track the first occurrence and its index
    seen = Dict{String, Int}()

    # Iterate backwards to prefer the first non-missing value when deduplicating
    for i in length(column_names):-1:1
        name, value = column_names[i], column_values[i]
        if !is_missing(value)
            if haskey(seen, name)
                # Update with non-missing value if found later
                column_values[seen[name]] = value
            else
                seen[name] = i  # Track the first non-missing occurrence
            end
        elseif !haskey(seen, name)
            # Even if it's missing, we need to track the first occurrence
            seen[name] = i
        end
    end

    # Filter the original arrays based on the indices stored in 'seen'
    # This will also sort them based on their original order preserved by iteration order in 'seen'
    filter_indices = sort(collect(values(seen)))

    # Assign new values to the beginning of the original arrays
    column_names[1:length(filter_indices)] = [column_names[i] for i in filter_indices]
    column_values[1:length(filter_indices)] = [column_values[i] for i in filter_indices]

    # Resize the original arrays to remove the extra elements
    resize!(column_names, length(filter_indices))
    resize!(column_values, length(filter_indices))

    nothing

end
