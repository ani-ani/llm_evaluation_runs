import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to wait for done with timeout
async def wait_for_done(dut, max_cycles=25):
    """Wait for done signal to go high, with cycle timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return cycle
    raise TestFailure(f"Timeout: done never went high after {max_cycles} cycles")

# Helper to set string array
def set_string(dut, test_string):
    """Set the string array from Python string. Null terminator is implicit."""
    # Convert to bytes and ensure null termination
    string_bytes = bytes(test_string, 'ascii') if test_string else b''
    
    # Set each byte
    for i in range(16):
        if i < len(string_bytes):
            dut.string[i].value = string_bytes[i]
        else:
            dut.string[i].value = 0  # Null or padding

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_strlen_empty(dut):
    """Test empty string: length should be 0"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test empty string
    set_string(dut, "")
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check result
    if not is_value_defined(dut.length.value):
        raise TestFailure("Length output is undefined (X/Z)")
    
    result = int(dut.length.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"Empty string: expected {expected}, got {result}")
    
    dut._log.info("Test 1 passed: empty string")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_strlen_single(dut):
    """Test single character string: 'x' should return 1"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    set_string(dut, "x")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.length.value):
        raise TestFailure("Length output is undefined")
    
    result = int(dut.length.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Single char 'x': expected {expected}, got {result}")
    
    dut._log.info("Test 2 passed: single character")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_strlen_long(dut):
    """Test longer string: 'asdasnakj' should return 9"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    set_string(dut, "asdasnakj")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.length.value):
        raise TestFailure("Length output is undefined")
    
    result = int(dut.length.value)
    expected = 9
    if result != expected:
        raise TestFailure(f"String 'asdasnakj': expected {expected}, got {result}")
    
    dut._log.info("Test 3 passed: long string")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_strlen_max_length(dut):
    """Test near-maximum length: 15 character string"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 15 character string
    set_string(dut, "aaaaaaaaaaaaaaa")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.length.value):
        raise TestFailure("Length output is undefined")
    
    result = int(dut.length.value)
    expected = 15
    if result != expected:
        raise TestFailure(f"15-char string: expected {expected}, got {result}")
    
    dut._log.info("Test 4 passed: max length")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_strlen_complex(dut):
    """Test with mixed characters: 'Hello World!'"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    set_string(dut, "Hello World!")
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.length.value):
        raise TestFailure("Length output is undefined")
    
    result = int(dut.length.value)
    expected = 12
    if result != expected:
        raise TestFailure(f"String 'Hello World!': expected {expected}, got {result}")
    
    dut._log.info("Test 5 passed: Hello World!")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_strlen_multiple_iterations(dut):
    """Test running strlen multiple times sequentially"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ("", 0),
        ("a", 1),
        ("abc", 3),
        ("test", 4),
        ("xy", 2)
    ]
    
    for test_str, expected in test_cases:
        set_string(dut, test_str)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if not is_value_defined(dut.length.value):
            raise TestFailure(f"Length output undefined for '{test_str}'")
        
        result = int(dut.length.value)
        if result != expected:
            raise TestFailure(f"Iteration '{test_str}': expected {expected}, got {result}")
    
    dut._log.info("Test 6 passed: multiple iterations")
