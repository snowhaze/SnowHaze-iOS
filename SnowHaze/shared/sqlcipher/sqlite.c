//
//  sqlite.c
//

//  Copyright © 2018 Illotros GmbH. All rights reserved.
//

#import "sqlite3.h"

const sqlite3_destructor_type TRANSIENT = SQLITE_TRANSIENT;
const char* sqlite3_fts5_api_pointer_type = "fts5_api_ptr";

int sqlite_option_no_param(int config) {
	return sqlite3_config(config);
}

int sqlite_option_one_int(int config, int value) {
	return sqlite3_config(config, value);
}

int sqlite_option_two_int64(int config, sqlite3_int64 value1, sqlite3_int64 value2) {
	return sqlite3_config(config, value1, value2);
}

int sqlite_option_context_context_int_string_fnpointer_int64(int config, void* context, void(*fn_pointer)(void*,int,const char*)) {
	return sqlite3_config(config, fn_pointer, context);
}

int sqlite_db_option_voidp_int_int(sqlite3* db, int config, void* value1, int value2, int value3) {
	return sqlite3_db_config(db, config, value1, value2, value3);
}

int sqlite_db_option_int_intp(sqlite3* db, int config, int value1, int* value2) {
	return sqlite3_db_config(db, config, value1, value2);
}
