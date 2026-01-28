import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for Q16.16 fixed-point
Q16_SCALE = 1 << 16
CLK_NS = 10
MAX_CYCLES = 50

def float_to_fixed(f):
    """Convert float to Q16.16 fixed-point"""
    return int(f * Q16_SCALE)

def fixed_to_float(v):
    """Convert Q16.16 fixed-point to float"""
    # Handle signed values
    if v >= (1 << 31):
        v = v - (1 << 32)
    return v / Q16_SCALE

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_triangle_area(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (a, h, expected_result)
    test_cases = [
        (5.0, 3.0, 7.5),
        (2.0, 2.0, 2.0),
        (10.0, 8.0, 40.0),
        (1.5, 4.0, 3.0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_val, h_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a_val}, h={h_val}, expected={expected}")
        
        try:
            # Convert to Q16.16 fixed-point
            a_fixed = float_to_fixed(a_val)
            h_fixed = float_to_fixed(h_val)
            
            # Clamp to 32-bit for inputs (signed)
            a_clamped = a_fixed & 0xFFFFFFFF
            h_clamped = h_fixed & 0xFFFFFFFF
            
            # Set inputs
            dut.a.value = a_clamped
            dut.h.value = h_clamped
            dut.start.value = 1
            
            # Wait for one cycle
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=100)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            result_float = fixed_to_float(result)
            
            # Allow small floating-point tolerance
            tolerance = 1e-3
            if abs(result_float - expected) > tolerance:
                raise TestFailure(
                    f"Expected {expected}, got {result_float} (0x{result:08X})"
                )
            
            passed += 1
            cocotb.log.info(f"  PASS: got {result_float}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
