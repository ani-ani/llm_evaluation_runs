import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def string_to_packed(s):
    """Convert binary string to packed bits (LSB = first char)"""
    packed = 0
    for i, char in enumerate(s):
        if char == '1':
            packed |= (1 << i)
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_xor(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (a_str, b_str, expected_str, len)
    test_cases = [
        ('111000', '101010', '010010', 6),
        ('1', '1', '0', 1),
        ('0101', '0000', '0101', 4),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_str, b_str, expected_str, length) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a='{a_str}', b='{b_str}' (len={length})")
        
        try:
            # Convert to packed bits
            a_packed = string_to_packed(a_str)
            b_packed = string_to_packed(b_str)
            expected_packed = string_to_packed(expected_str)
            
            # Set inputs
            dut.a.value = a_packed
            dut.b.value = b_packed
            dut.len.value = length
            
            # Start operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Verify only relevant bits
            mask = (1 << length) - 1
            result_masked = result & mask
            expected_masked = expected_packed & mask
            
            if result_masked != expected_masked:
                raise TestFailure(f"Expected {expected_str} ({expected_packed:08b}), got {result_masked:08b} (masked)")
            
            passed += 1
            cocotb.log.info(f"  PASS: got {expected_str}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")
