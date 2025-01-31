cmake_minimum_required(VERSION 3.20)
# note: 3.19+ needed for JSON parsing

# json_get_subprops("${_json}" [key,key...] PROPERTIES property [property...])
function(json_get_subprops _json)
    cmake_parse_arguments(_sub "" "" "PROPERTIES" ${ARGN})
    foreach(arg IN LISTS _sub_PROPERTIES)
        string(JSON value ERROR_VARIABLE jsonerror GET "${_json}" ${_sub_UNPARSED_ARGUMENTS} "${arg}")
        set(${arg} ${value} PARENT_SCOPE)
    endforeach()
endfunction()

# example: coalesce(VAR first second third) -> first truthy value found
function(coalesce _outvar)
    list(FILTER ARGN EXCLUDE REGEX "-NOTFOUND|^$|^null$|^undefined$")
    list(GET ARGN 0 _tmp)
    set(${_outvar} ${_tmp} PARENT_SCOPE)
endfunction()

# sets OUTVAR to first non-null value
# example: json_coalesce_subprops("${_json}" "repos" "${name}" PROPERTIES branch tag commit)
function(json_coalesce_subprops _json _OUTVAR)
    cmake_parse_arguments(_sub "" "" "PROPERTIES" ${ARGN})
    foreach(_arg IN LISTS _sub_PROPERTIES)
        string(JSON _value ERROR_VARIABLE jsonerror GET "${_json}" ${_sub_UNPARSED_ARGUMENTS} "${_arg}")
        if (NOT ${_value} MATCHES "-NOTFOUND|^$|^null$|^undefined$")
          set(${_OUTVAR} ${_value} PARENT_SCOPE)
          return()
        endif()
    endforeach()
    set(${_OUTVAR} "" PARENT_SCOPE)
endfunction()

# examples:
#   # evaluate cmake code block for each key-value pair
#   json_foreach("${_json}" "key1;key2" "message(subproperty key={0} value={1})")
# 
#   function(callback key value userValue)
#     message("subproperty key=${key} value=${value} userValue=${userValue}")
#   endfunction()
#   # evaluate specific member key-value pairs
#   json_foreach("${_json}" "key1;key2" callback "myuservalue")  
#   # enumerate top-level key-value pairs
#   json_foreach("${_json}" "" callback)
function(json_foreach _json _objectName _functionOrEval _userValue)
  if (NOT _json)
    return()
  endif()
  string(JSON _n LENGTH "${_json}" ${_objectName})
  MATH(EXPR _n "${_n}-1")
  foreach(_i RANGE 0 ${_n})
    string(JSON _key MEMBER "${_json}" ${_objectName} ${_i})
    string(JSON _value GET "${_json}" ${_objectName} ${_key})
    if (_functionOrEval MATCHES "[(]") # evaluate as cmake code
      # message("evaluating as code: ${_functionOrEval}")
      set(_tmp ${_functionOrEval})
      string(REPLACE "{0}" ${_key} _tmp ${_tmp})
      string(REPLACE "{1}" ${_value} _tmp ${_tmp})
      string(REPLACE "{2}" "${_userValue}" _tmp ${_tmp})
      cmake_language(EVAL CODE ${_tmp})
    else() # invoke as functionname
      # message("evaluating as function: ${_functionOrEval}(${_key} ${_value} ${_userValue})")
      cmake_language(CALL ${_functionOrEval} ${_key} ${_value} "${_userValue}")
    endif()
  endforeach()
endfunction()

# resolve global properties into corresponding ~local variables
# eg: get_component_props(Vulkan-Headers cmake_extra patch_command)
#     message("cmake_extra=${cmake_extra} patch_command=${patch_command}")
function(get_component_props _comp)
  foreach(_arg ${ARGN})
    get_property(_value GLOBAL PROPERTY "${_comp}_${_arg}")
    set(${_arg} "${_value}" PARENT_SCOPE)
  endforeach()
endfunction()

