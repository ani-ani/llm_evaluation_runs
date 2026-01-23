import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_sub_array_sum(dut):
    """Test Kadane's algorithm implementation"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (array_values, expected_result, description)
    test_cases = [
        ([-2, -3, 4, -1, -2, 1, 5, -3], 7, "Test 1: Original example"),
        ([-3, -4, 5, -2, -3, 2, 6, -4], 8, "Test 2: All negative mixed"),
        ([-4, -5, 6, -3, -4, 3, 7, -5], 10, "Test 3: Higher sum"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 36, "Test 4: All positive"),
        ([-1, -2, -3, -4, -5, -6, -7, -8], 0, "Test 5: All negative"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (array_vals, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {array_vals}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write array elements individually
            for j, val in enumerate(array_vals):
                if j >= ARRAY_SIZE:
                    break
                # Convert to signed representation
                signed_val = from_signed(val, DATA_WIDTH)
                # Access port by name
                port_name = f"arr_{j}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = signed_val
                else:
                    raise TestFailure(f"Port {port_name} not found")
            
            # Set length
            dut.len.value = len(array_vals)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            raw_result = int(dut.result.value)
            result = to_signed(raw_result, RESULT_WIDTH)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Summary: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")