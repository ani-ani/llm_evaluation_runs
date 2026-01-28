import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Function to compute expected result in Python
def compute_expected(string):
    summ = 0
    for char in string:
        summ += (ord(char) - ord('a') + 1)
    if summ % 26 == 0:
        return ord('z')
    else:
        return ord('a') + (summ % 26) - 1

# Task to wait for done
async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reset task
async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_get_char(dut):
    # Setup clock if it exists
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units="ns")
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_strings = ["abc", "gfg", "ab", "zzzzzzzzzzzzzzzz"] # Last one for full 16 chars
    
    passed = 0
    failed = 0

    for s in test_strings:
        # Pad string to 16 characters with 'a' if needed, or treat full 16
        # The spec says max 16. We'll assume input is always 16 cycles worth of data.
        # If string is shorter, we can pad with 'a' (which adds 1 to sum, simple padding)
        # Or better, use the string length exactly if the module handles it, but spec implies fixed loop or max.
        # Let's stick to the string provided, padded to 16 with 'a' to be safe for the "max 16" constraint.
        padded_s = s.ljust(16, 'a') 
        
        expected = compute_expected(s) # Calculation based on actual string content
        
        cocotb.log.info(f"Testing string: '{s}' (padded to 16 chars), Expected: {chr(expected)} ({expected})")
        
        # Start sequence
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Interaction loop: Simulate the memory based on idx_out
        max_cycles = 50
        cycles = 0
        
        while True:
            # Check if done
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) == 1:
                    break
            
            # Provide character data based on index
            if has_signal(dut, 'idx_out') and is_value_defined(dut.idx_out.value):
                idx = int(dut.idx_out.value)
                # Only drive if index is within 0-15
                if idx < 16:
                    char_code = ord(padded_s[idx])
                    dut.char_in.value = char_code
            
            # Check for timeout
            cycles += 1
            if cycles > max_cycles:
                raise TestFailure(f"Loop timeout for string '{s}'")
                
            await RisingEdge(dut.clk)

        # Read result
        if not has_signal(dut, 'result'):
            raise TestFailure("Result signal not found")
            
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result value undefined")
            
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"FAIL: String '{s}'. Expected {chr(expected)} ({expected}), got {chr(result)} ({result})")
            failed += 1
        else:
            cocotb.log.info(f"PASS: String '{s}'. Result: {chr(result)}")
            passed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
