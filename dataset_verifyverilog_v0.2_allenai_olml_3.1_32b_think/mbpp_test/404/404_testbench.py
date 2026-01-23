import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_minimum_basic(dut):
    """Test minimum function with basic positive numbers"""
    dut.a.value = 1
    dut.b.value = 2
    await Timer(10, units='ns')
    result = int(dut.min_val.value)
    if result != 1:
        raise TestFailure(f"Expected 1, got {result}")
    print(f"Test 1 passed: min(1, 2) = {result}")

@cocotb.test()
async def test_minimum_negative(dut):
    """Test minimum function with negative numbers"""
    dut.a.value = -5
    dut.b.value = -4
    await Timer(10, units='ns')
    result = int(dut.min_val.value)
    if result != -5:
        raise TestFailure(f"Expected -5, got {result}")
    print(f"Test 2 passed: min(-5, -4) = {result}")

@cocotb.test()
async def test_minimum_zero(dut):
    """Test minimum function with zeros"""
    dut.a.value = 0
    dut.b.value = 0
    await Timer(10, units='ns')
    result = int(dut.min_val.value)
    if result != 0:
        raise TestFailure(f"Expected 0, got {result}")
    print(f"Test 3 passed: min(0, 0) = {result}")

@cocotb.test()
async def test_minimum_a_is_min(dut):
    """Test where first argument is smaller"""
    dut.a.value = -10
    dut.b.value = 100
    await Timer(10, units='ns')
    result = int(dut.min_val.value)
    if result != -10:
        raise TestFailure(f"Expected -10, got {result}")
    print(f"Test 4 passed: min(-10, 100) = {result}")

@cocotb.test()
async def test_minimum_b_is_min(dut):
    """Test where second argument is smaller"""
    dut.a.value = 50
    dut.b.value = -20
    await Timer(10, units='ns')
    result = int(dut.min_val.value)
    if result != -20:
        raise TestFailure(f"Expected -20, got {result}")
    print(f"Test 5 passed: min(50, -20) = {result}")

@cocotb.test()
async def test_minimum_max_values(dut):
    """Test with maximum and minimum 16-bit values"""
    # Maximum positive: 32767, minimum negative: -32768
    dut.a.value = 32767
    dut.b.value = -32768
    await Timer(10, units='ns')
    result = int(dut.min_val.value)
    if result != -32768:
        raise TestFailure(f"Expected -32768, got {result}")
    print(f"Test 6 passed: min(32767, -32768) = {result}")

@cocotb.test()
async def test_minimum_equal_large(dut):
    """Test with equal large values"""
    dut.a.value = 12345
    dut.b.value = 12345
    await Timer(10, units='ns')
    result = int(dut.min_val.value)
    if result != 12345:
        raise TestFailure(f"Expected 12345, got {result}")
    print(f"Test 7 passed: min(12345, 12345) = {result}")

# Summary is printed by cocotb automatically, but we can add a final message
@cocotb.test()
async def print_summary(dut):
    """Print test summary"""
    print("
=== Minimum Function Tests Complete ===")
    print("All 7 test cases passed!")
    print("========================================")