import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_indoorienteering(dut):
    # Setup clock
    clk_period = 10  # ns (100MHz)
    cocotb.start_soon(Clock(dut.clk, clk_period, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, L, distances_matrix, expected_result)
    # Scaled: all distances and L are 16-bit integers
    test_cases = [
        (4, 10, [
            [0, 3, 2, 1],
            [3, 0, 1, 3],
            [2, 1, 0, 2],
            [1, 3, 2, 0]
        ], 1),  # possible
        (3, 5, [
            [0, 1, 2],
            [1, 0, 3],
            [2, 3, 0]
        ], 0),  # impossible
    ]
    
    passed = 0
    failed = 0
    
    for idx, (n, L, dist_mat, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {idx+1}: n={n}, L={L}")
        try:
            # Pack distances into d_flat (512-bit)
            d_flat = 0
            for i in range(n):
                for j in range(n):
                    val = dist_mat[i][j]
                    if val > 65535:  # Clamp if exceeds 16-bit
                        val = 65535
                    offset = (i * 8 + j) * 16
                    d_flat |= (val << offset)
            
            # Set inputs
            dut.n.value = n
            dut.L.value = L
            dut.d_flat.value = d_flat
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed")