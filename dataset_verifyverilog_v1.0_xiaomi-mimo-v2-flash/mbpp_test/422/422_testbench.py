import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

DATA_WIDTH, CLK_NS = 8, 10
MAX_CYCLES = 300  # 1-255 compute + 32 divide + overhead

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_avg_cube(dut):
    # Check required signals
    if not has_signal(dut, 'clk'):
        cocotb.log.error("Sequential module requires 'clk' signal")
        raise TestFailure("Missing 'clk' signal")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, expected_float, description)
    test_cases = [
        (1, 1.0, "n=1: 1^3 / 1 = 1"),
        (2, 4.5, "n=2: (1+8)/2 = 4.5"),
        (3, 12.0, "n=3: (1+8+27)/3 = 12"),
        (10, 302.5, "n=10: large test"),
    ]
    
    passed = 0
    failed = 0
    
    for n_in, expected_float, desc in test_cases:
        cocotb.log.info(f"Test: {desc}")
        
        # Convert expected to Q16.16
        expected_q16 = int(expected_float * (1 << 16))
        
        try:
            # Input n (8-bit)
            dut.n.value = clamp_to_width(n_in, 8)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # For Q16.16, check tolerance of +/- 1 unit
            tolerance = 1  # 1/65536 = 0.000015
            diff = abs(result - expected_q16)
            
            if diff > tolerance:
                actual_float = result / (1 << 16)
                raise TestFailure(
                    f"Expected {expected_float:.6f} (0x{expected_q16:08X}), "
                    f"got {actual_float:.6f} (0x{result:08X}), diff={diff}"
                )
            
            passed += 1
            cocotb.log.info(f"  PASS: result=0x{result:08X} ({actual_float:.6f})")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Additional edge case: n=255 (max)
    cocotb.log.info("Edge case: n=255 (max)")
    dut.n.value = 255
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    result = int(dut.result.value)
    actual_float = result / (1 << 16)
    cocotb.log.info(f"  n=255 result: {actual_float:.6f} (0x{result:08X})")
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")