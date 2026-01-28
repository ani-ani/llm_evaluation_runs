import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert integer to binary string format
def to_binary_string(val):
    if val == -1:
        return "-1"
    return "0b" + bin(val)[2:]

# Wrapper to drive the DUT and return the result as a string
async def candidate(dut, n, m):
    # Drive inputs
    dut.n.value = n
    dut.m.value = m
    dut.start.value = 1
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done with timeout (max 10 cycles)
    done_received = False
    for _ in range(10):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            done_received = True
            break
    
    if not done_received:
        raise TestFailure("Timeout waiting for done signal")
    
    # Check for undefined outputs
    if not is_value_defined(dut.error.value) or not is_value_defined(dut.result.value):
        raise TestFailure("Output signals are undefined")
    
    error = int(dut.error.value)
    result = int(dut.result.value)
    
    if error == 1:
        return -1
    else:
        # Verify result fits in 16 bits (problem constraint)
        return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rounded_avg(dut):
    """Test the rounded_avg module."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, m, expected_string)
    test_cases = [
        (1, 5, "0b11"),
        (7, 13, "0b1010"),
        (964, 977, "0b1111001010"),
        (996, 997, "0b1111100100"),
        (560, 851, "0b1011000010"),
        (185, 546, "0b101101110"),
        (362, 496, "0b110101101"),
        (350, 902, "0b1001110010"),
        (197, 233, "0b11010111"),
        (7, 5, "-1"),
        (5, 1, "-1"),
        (5, 5, "0b101")
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Running {total} test cases...")
    
    for n, m, expected_str in test_cases:
        
        # Determine expected integer value from expected string
        if expected_str == "-1":
            expected_val = -1
        else:
            expected_val = int(expected_str[2:], 2)
        
        # Run DUT
        try:
            hdl_val = await candidate(dut, n, m)
        except TestFailure as e:
            dut._log.error(f"Test failed for n={n}, m={m}: {e}")
            continue
        
        # Compare
        if hdl_val == expected_val:
            passed += 1
        else:
            actual_str = to_binary_string(hdl_val)
            dut._log.error(f"Test failed for n={n}, m={m}: Expected {expected_str}, Got {actual_str} (Int: {expected_val} vs {hdl_val})")
            
    dut._log.info(f"{passed}/{total} tests passed")
    
    if passed < total:
        raise TestFailure(f"{total - passed} tests failed")
