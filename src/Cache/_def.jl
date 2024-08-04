# A dictionary to hold the cache, initialized later
const _cache_ref = Ref{Dict{Any, Any}}()

function add_to_cache end
function get_from_cache end
function remove_from_cache end
function clear_cache end
function cache_keys end
function cache_values end
function _ensure_cache_initialized end
function get_db_entry_key_for_cache end
function generate_fk2pk_mapping_cache end
function generate_cache end
function __init__ end
