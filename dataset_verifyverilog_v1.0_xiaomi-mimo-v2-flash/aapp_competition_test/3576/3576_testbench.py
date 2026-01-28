import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
CLK_NS = 10
MOD = 1000000007

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

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_evasion(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test case: R=5, C=4, K=2 (scaled down from huge input)
    # We need to adapt the testbench to match the simplified HDL spec
    # The HDL spec says R, C <= 8. 
    # Let's test R=5, C=4, K=2.
    # Python calculation for expected value:
    R, C, K = 5, 4, 2
    
    # Calculate expected probability
    total_pairs = R * C * R * C
    safe_pairs = 0
    for pr in range(R):
        for pc in range(C):
            for yr in range(R):
                for yc in range(C):
                    if abs(pr - yr) + abs(pc - yc) > K:
                        safe_pairs += 1
    
    # Calculate modular inverse of total_pairs
    # Python pow(base, -1, mod) is available in 3.8+
    try:
        inv_total = pow(total_pairs, -1, MOD)
        expected = (safe_pairs * inv_total) % MOD
    except:
        # Fallback for old python versions if needed
        expected = 0
    
    cocotb.log.info(f"Test case R={R}, C={C}, K={K}")
    cocotb.log.info(f"Total pairs: {total_pairs}, Safe pairs: {safe_pairs}")
    cocotb.log.info(f"Expected result: {expected}")
    
    # Drive inputs
    dut.R.value = R
    dut.C.value = C
    dut.K.value = K
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 10000
        done = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Timeout after {max_cycles} cycles")
        
        # Read result
        if is_value_defined(dut.result.value):
            result = int(dut.result.value)
            cocotb.log.info(f"Got result: {result}")
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
        else:
            raise TestFailure("Result is undefined")
    else:
        # Combinational logic
        await Timer(100, units='ns')
        if is_value_defined(dut.result.value):
            result = int(dut.result.value)
            cocotb.log.info(f"Got result: {result}")
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
