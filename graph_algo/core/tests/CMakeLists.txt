add_executable(ga_test_core test_core.cpp)
target_link_libraries(ga_test_core PRIVATE ga::core)
add_test(NAME ga_test_core COMMAND ga_test_core)

add_executable(ga_test_gen_bench test_gen_bench.cpp)
target_link_libraries(ga_test_gen_bench PRIVATE ga::core)
add_test(NAME ga_test_gen_bench COMMAND ga_test_gen_bench)
