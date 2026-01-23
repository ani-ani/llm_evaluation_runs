import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_remove_nested(dut):
    # Helper function to convert Python list to input format
    def format_input(py_list):
        # Pad to 8 elements with 0xFF if needed
        while len(py_list) < 8:
            py_list.append(0xFF)
        return py_list[:8]

    # Helper function to format expected output
    def format_expected(py_list):
        # Pad to 8 elements with 0xFF
        while len(py_list) < 8:
            py_list.append(0xFF)
        return py_list[:8]

    # Helper function to check results
    def check_result(actual, expected, msg):
        for i in range(8):
            if actual[i] != expected[i]:
                print(f"FAIL: {msg}")
                print(f"  Index {i}: Expected {expected[i]}, Got {actual[i]}")
                return False
        return True

    # Test Case 1: (1, 5, 7, (4, 6), 10)
    # Input: [1, 5, 7, 0xFF, 10, 0xFF, 0xFF, 0xFF]
    # Expected: [1, 5, 7, 10, 0xFF, 0xFF, 0xFF, 0xFF]
    dut.data_in.value = format_input([1, 5, 7, 0xFF, 10])
    await Timer(1, units='ns')
    actual = [int(dut.data_out[i]) for i in range(8)]
    expected = format_expected([1, 5, 7, 10])
    assert check_result(actual, expected, "Test Case 1 Failed"), "Assertion failed"
    print("Test Case 1 Passed")

    # Test Case 2: (2, 6, 8, (5, 7), 11)
    # Input: [2, 6, 8, 0xFF, 11, 0xFF, 0xFF, 0xFF]
    # Expected: [2, 6, 8, 11, 0xFF, 0xFF, 0xFF, 0xFF]
    dut.data_in.value = format_input([2, 6, 8, 0xFF, 11])
    await Timer(1, units='ns')
    actual = [int(dut.data_out[i]) for i in range(8)]
    expected = format_expected([2, 6, 8, 11])
    assert check_result(actual, expected, "Test Case 2 Failed"), "Assertion failed"
    print("Test Case 2 Passed")

    # Test Case 3: (3, 7, 9, (6, 8), 12)
    # Input: [3, 7, 9, 0xFF, 12, 0xFF, 0xFF, 0xFF]
    # Expected: [3, 7, 9, 12, 0xFF, 0xFF, 0xFF, 0xFF]
    dut.data_in.value = format_input([3, 7, 9, 0xFF, 12])
    await Timer(1, units='ns')
    actual = [int(dut.data_out[i]) for i in range(8)]
    expected = format_expected([3, 7, 9, 12])
    assert check_result(actual, expected, "Test Case 3 Failed"), "Assertion failed"
    print("Test Case 3 Passed")

    # Test Case 4: (3, 7, 9, (6, 8), (5, 12), 12)
    # Input: [3, 7, 9, 0xFF, 0xFF, 12, 0xFF, 0xFF]
    # Expected: [3, 7, 9, 12, 0xFF, 0xFF, 0xFF, 0xFF]
    dut.data_in.value = format_input([3, 7, 9, 0xFF, 0xFF, 12])
    await Timer(1, units='ns')
    actual = [int(dut.data_out[i]) for i in range(8)]
    expected = format_expected([3, 7, 9, 12])
    assert check_result(actual, expected, "Test Case 4 Failed"), "Assertion failed"
    print("Test Case 4 Passed")

    # Test Case 5: Edge case - All integers
    # Input: [1, 2, 3, 4, 5, 6, 7, 8]
    # Expected: [1, 2, 3, 4, 5, 6, 7, 8]
    dut.data_in.value = format_input([1, 2, 3, 4, 5, 6, 7, 8])
    await Timer(1, units='ns')
    actual = [int(dut.data_out[i]) for i in range(8)]
    expected = format_expected([1, 2, 3, 4, 5, 6, 7, 8])
    assert check_result(actual, expected, "Test Case 5 Failed"), "Assertion failed"
    print("Test Case 5 Passed")

    # Test Case 6: Edge case - All tuples
    # Input: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    # Expected: [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    dut.data_in.value = format_input([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
    await Timer(1, units='ns')
    actual = [int(dut.data_out[i]) for i in range(8)]
    expected = [0xFF] * 8
    assert check_result(actual, expected, "Test Case 6 Failed"), "Assertion failed"
    print("Test Case 6 Passed")

    print("All 6/6 tests passed")