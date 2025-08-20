@kwdef mutable struct FKInfo
    referencing_table::String
    referencing_schema::String
    referencing_col::String
    referenced_table::String
    referenced_schema::String
    referenced_col::String
    constraint_name::String
end
