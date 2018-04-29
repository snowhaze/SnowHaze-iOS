//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include "sqlite3.h" // import leads to the system header being imported

const sqlite3_destructor_type TRANSIENT;
const char* sqlite3_fts5_api_pointer_type;

int sqlite_option_no_param(int config);
int sqlite_option_one_int(int config, int value);
int sqlite_option_two_int64(int config, sqlite3_int64 value1, sqlite3_int64 value2);
int sqlite_option_context_context_int_string_fnpointer_int64(int config, void* context, void(*fn_pointer)(void*,int,const char*));

int sqlite_db_option_voidp_int_int(sqlite3* db, int config, void* value1, int value2, int value3);
int sqlite_db_option_int_intp(sqlite3* db, int config, int value1, int* value2);
