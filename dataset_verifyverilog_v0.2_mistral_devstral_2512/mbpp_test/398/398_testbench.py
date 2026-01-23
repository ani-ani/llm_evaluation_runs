import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

def str_to_bytes(s):
    """Convert string to 64-bit value (8 bytes, little-endian)"""
    result = 0
    for i, char in enumerate(s[:8]):
        result |= (ord(char) << (i * 8))
    return result

@cocotb.test()
async def test_sum_of_digits_basic(dut):
    """Test basic case: [10, 2, 56] -> 14"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_count.value = 0
    for i in range(8):
        dut.str_data[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: [10, 2, 56] -> 14
    dut.num_count.value = 3
    dut.str_data[0].value = str_to_bytes("10")
    dut.str_data[1].value = str_to_bytes("2")
    dut.str_data[2].value = str_to_bytes("56")
    for i in range(3, 8):
        dut.str_data[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 200
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 1: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 1 Result: {result} (expected 14)")
    assert result == 14, f"Test 1 failed: got {result}, expected 14"

@cocotb.test()
async def test_sum_of_digits_with_negative(dut):
    """Test with negative numbers: [10, 20, -4, 5, -70] -> 19"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_count.value = 0
    for i in range(8):
        dut.str_data[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: [10, 20, -4, 5, -70] -> 19
    dut.num_count.value = 5
    dut.str_data[0].value = str_to_bytes("10")
    dut.str_data[1].value = str_to_bytes("20")
    dut.str_data[2].value = str_to_bytes("-4")
    dut.str_data[3].value = str_to_bytes("5")
    dut.str_data[4].value = str_to_bytes("-70")
    for i in range(5, 8):
        dut.str_data[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 200
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 2: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 2 Result: {result} (expected 19)")
    assert result == 19, f"Test 2 failed: got {result}, expected 19"

@cocotb.test()
async def test_sum_of_digits_with_non_digits(dut):
    """Test ignoring non-digits: [10, 20, 4, 5, 'b', 70, 'a'] -> 19"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_count.value = 0
    for i in range(8):
        dut.str_data[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: [10, 20, 4, 5, 'b', 70, 'a'] -> 19
    # Note: 'b' and 'a' are non-digits, should be ignored
    # This means we have 7 strings but only 5 valid number strings
    dut.num_count.value = 7
    dut.str_data[0].value = str_to_bytes("10")
    dut.str_data[1].value = str_to_bytes("20")
    dut.str_data[2].value = str_to_bytes("4")
    dut.str_data[3].value = str_to_bytes("5")
    dut.str_data[4].value = str_to_bytes("b")
    dut.str_data[5].value = str_to_bytes("70")
    dut.str_data[6].value = str_to_bytes("a")
    dut.str_data[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 200
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 3: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 3 Result: {result} (expected 19)")
    assert result == 19, f"Test 3 failed: got {result}, expected 19"

@cocotb.test()
async def test_sum_of_digits_edge_cases(dut):
    """Test edge cases: empty string, single digit, max value"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_count.value = 0
    for i in range(8):
        dut.str_data[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 4: ["999", "-88", "0", "12345678"] -> 9+9+9 + 8+8 + 0 + 1+2+3+4+5+6+7+8 = 70
    dut.num_count.value = 4
    dut.str_data[0].value = str_to_bytes("999")
    dut.str_data[1].value = str_to_bytes("-88")
    dut.str_data[2].value = str_to_bytes("0")
    dut.str_data[3].value = str_to_bytes("12345678")
    for i in range(4, 8):
        dut.str_data[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 200
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 4: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 4 Result: {result} (expected 70)")
    assert result == 70, f"Test 4 failed: got {result}, expected 70"

@cocotb.test()
async def test_sum_of_digits_no_numbers(dut):
    """Test with no numbers (num_count = 0) -> 0"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_count.value = 0
    for i in range(8):
        dut.str_data[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 5: num_count = 0
    dut.num_count.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 200
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Test 5: Timeout waiting for done")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 5 Result: {result} (expected 0)")
    assert result == 0, f"Test 5 failed: got {result}, expected 0"

print("All test cases passed!")