add_executable(sa_test_core test_core.cpp)
target_link_libraries(sa_test_core PRIVATE sa::core)
add_test(NAME sa_test_core COMMAND sa_test_core)

add_executable(sa_test_gen_bench test_gen_bench.cpp)
target_link_libraries(sa_test_gen_bench PRIVATE sa::core)
add_test(NAME sa_test_gen_bench COMMAND sa_test_gen_bench)

add_executable(sa_test_fuzz test_fuzz.cpp)
target_link_libraries(sa_test_fuzz PRIVATE sa::core)
add_test(NAME sa_test_fuzz COMMAND sa_test_fuzz)
