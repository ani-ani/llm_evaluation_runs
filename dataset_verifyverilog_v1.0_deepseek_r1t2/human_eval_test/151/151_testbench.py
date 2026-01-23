import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def check_odd_positive(value, bits=8):
    """Check if signed 8-bit integer is positive and odd."""
    # Convert to signed if needed
    if value >= (1 << (bits - 1)):
        signed_val = value - (1 << bits)
    else:
        signed_val = value
    
    return (signed_val >= 0) and (signed_val % 2 != 0)

def compute_expected(arr):
    """Compute expected result."""
    total = 0
    for val in arr:
        # Handle signed representation
        if val >= 128:  # If MSB set, it's negative
            signed_val = val - 256
        else:
            signed_val = val
        
        if signed_val >= 0 and (signed_val % 2 != 0):
            total += signed_val * signed_val
    return total

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_double_the_difference(dut):
    """Test double_the_difference module."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (description, input_array, expected_sum)
        ("Empty array", [0, 0, 0, 0, 0, 0, 0, 0], 0),
        ("Simple odd positives", [5, 4, 0, 0, 0, 0, 0, 0], 25),
        ("All negative", [0xF6, 0xEC, 0xE2, 0, 0, 0, 0, 0], 0),  # -10, -20, -30
        ("Mixed floats treated as 0", [1, 2, 3, 0, 0, 0, 0, 0], 10),  # 0.1→1, 0.2→2, 0.3→3
        ("One odd", [0, 0, 0, 0, 0, 0, 9, 0], 81),  # -2, 8 -> but 8 is even, -2 filtered, 9 is odd
        ("Two odds", [3, 5, 0, 0, 0, 0, 0, 0], 34),
        ("All odd positives", [1, 3, 5, 7, 9, 11, 13, 15], 850),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (desc, input_arr, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Load input array
        for j in range(8):
            dut.arr[j].value = input_arr[j]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 12 cycles: 8 for processing + states)
        timeout_cycles = 20
        done_received = False
        
        for cycle in range(timeout_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Test {i+1}: Done signal not received after {timeout_cycles} cycles")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result has X/Z values")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {i+1} ({desc}): expected {expected}, got {result}")
        
        dut._log.info(f"  Result: {result} (Expected: {expected}) [PASS]")
        passed += 1
        
        # Wait for idle
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases and boundary values."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    edge_cases = [
        ("Max positive odd", [127, 127, 127, 127, 127, 127, 127, 127], 8 * 127 * 127),
        ("Minimum odd positive", [1, 0, 0, 0, 0, 0, 0, 0], 1),
        ("Zero included", [0, 1, 0, 3, 0, 0, 0, 0], 10),
        ("Only even positive", [2, 4, 6, 8, 10, 12, 14, 16], 0),
        ("Negative and positive mix", [0xFF, 0xFD, 1, 3, 0xFE, 0, 5, 0], 35),  # -1, -3, 1, 3, -2, 5
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for i, (desc, input_arr, expected) in enumerate(edge_cases):
        dut._log.info(f"Edge test {i+1}: {desc}")
        
        for j in range(8):
            dut.arr[j].value = input_arr[j]
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for cycle in range(20):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Edge test {i+1}: Timeout")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Edge test {i+1}: Undefined result")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Edge test {i+1} ({desc}): expected {expected}, got {result}")
        
        dut._log.info(f"  Result: {result} [PASS]")
        passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nEdge tests: {passed}/{total} passed")
    if passed != total:
        raise TestFailure(f"Edge tests: only {passed}/{total} passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_randomized(dut):
    """Test with random inputs."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    random.seed(42)
    num_tests = 10
    passed = 0
    
    for test_num in range(num_tests):
        # Generate random array
        input_arr = [random.randint(0, 255) for _ in range(8)]
        expected = compute_expected(input_arr)
        
        dut._log.info(f"Random test {test_num+1}: {input_arr}")
        
        # Load inputs
        for j in range(8):
            dut.arr[j].value = input_arr[j]
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for cycle in range(20):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Random test {test_num+1}: Timeout")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Random test {test_num+1}: Undefined result")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Random test {test_num+1}: expected {expected}, got {result}")
        
        dut._log.info(f"  Result: {result} [PASS]")
        passed += 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nRandom tests: {passed}/{num_tests} passed")
    if passed != num_tests:
        raise TestFailure(f"Random tests: only {passed}/{num_tests} passed")
