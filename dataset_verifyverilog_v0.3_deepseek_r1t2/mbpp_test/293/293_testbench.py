import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_q16_16(f):
    return int(f * 65536)

def q16_16_to_float(q):
    return q / 65536.0

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

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

async def start_computation(dut, w, h):
    dut.w.value = w
    dut.h.value = h
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pyt(dut):
    """Test pythagoras_third_side module with fixed-point validation."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (7, 8, 10.63014581273465),
        (3, 4, 5.0),
        (7, 15, 16.55294535724685),
    ]
    
    passed = 0
    failed = 0
    
    for i, (w, h, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: w={w}, h={h}, expected={expected}")
        
        try:
            await start_computation(dut, w, h)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_raw = int(dut.result.value)
            result_float = q16_16_to_float(result_raw)
            
            # Expected in Q16.16
            expected_fixed = float_to_q16_16(expected)
            
            # Allow small tolerance for fixed-point rounding
            # 0.0001 float error = ~6.55 in Q16.16
            tolerance = 15
            
            if abs(result_raw - expected_fixed) > tolerance:
                raise TestFailure(
                    f"Expected {expected} ({expected_fixed}), "
                    f"got {result_float} ({result_raw}), diff={abs(result_raw - expected_fixed)}"
                )
            
            cocotb.log.info(f"  PASS: {result_float:.6f} (raw={result_raw})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")