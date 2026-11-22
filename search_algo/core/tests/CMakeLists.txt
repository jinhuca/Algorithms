add_executable(se_test_core test_core.cpp)
target_link_libraries(se_test_core PRIVATE se::core)
add_test(NAME se_test_core COMMAND se_test_core)

add_executable(se_test_gen_bench test_gen_bench.cpp)
target_link_libraries(se_test_gen_bench PRIVATE se::core)
add_test(NAME se_test_gen_bench COMMAND se_test_gen_bench)

add_executable(se_test_fuzz test_fuzz.cpp)
target_link_libraries(se_test_fuzz PRIVATE se::core)
add_test(NAME se_test_fuzz COMMAND se_test_fuzz)
