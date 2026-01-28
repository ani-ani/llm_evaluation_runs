import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_binary_seq(dut):
    CLK_NS = 10
    DATA_WIDTH = 16
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, expected result)
    test_cases = [
        (1, 2.0),
        (2, 6.0),
        (3, 20.0),
        (0, 1.0)  # Additional test for n=0
    ]
    
    passed = 0
    failed = 0
    
    for n_val, exp in test_cases:
        cocotb.log.info(f"Testing n={n_val}, expected result={exp}")
        try:
            # Set inputs
            dut.n.value = n_val
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_q8_8 = int(dut.result.value)
            result_float = result_q8_8 / 256.0
            
            # Compare with expected
            expected_int = int(exp * 256)
            if result_q8_8 != expected_int:
                raise TestFailure(f"Expected {exp} (Q8.8 {expected_int}), got {result_float} (Q8.8 {result_q8_8})")
            
            passed += 1
            cocotb.log.info(f"  PASS: n={n_val} -> {result_float}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Short delay between tests
        await Timer(50, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
    
    cocotb.log.info(f"All {passed} tests passed!")