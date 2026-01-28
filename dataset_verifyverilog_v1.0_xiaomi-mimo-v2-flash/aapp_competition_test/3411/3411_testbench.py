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

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_alternating_chain(dut):
    # Parameters matching the Verilog spec
    N = 16
    DATA_WIDTH = 8
    COST_WIDTH = 16
    RESULT_WIDTH = 24
    CLK_NS = 10

    # Setup clock if present
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
    else:
        # Combinational circuit
        await Timer(1, units='ns')

    # Helper to run a test case
    async def run_test(scores, c_cost, r_cost):
        # Reset inputs
        if has_signal(dut, 'start'):
            dut.start.value = 0
        dut.c_in.value = c_cost
        dut.r_in.value = r_cost
        
        # Wait for reset to stabilize
        await RisingEdge(dut.clk)

        # Load scores serially
        if has_signal(dut, 'start'):
            dut.start.value = 1
            for s in scores:
                # Clamp signed value to 8 bits
                dut.s_in.value = s & 0xFF
                await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # If parallel load (unlikely for spec, but safe check)
            if has_signal(dut, 's_in_0'):
                for i, s in enumerate(scores):
                    getattr(dut, f's_in_{i}').value = s & 0xFF
            await RisingEdge(dut.clk)

        # Wait for done signal or fixed cycles if done missing
        if has_signal(dut, 'done'):
            cycles = 0
            while True:
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
                cycles += 1
                if cycles > 200:
                    raise TestFailure("Timeout waiting for 'done' signal")
        else:
            # If no done signal, wait fixed cycles based on N=16
            for _ in range(30):
                await RisingEdge(dut.clk)

        # Check result
        if not has_signal(dut, 'result'):
             raise TestFailure("Result signal missing")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined (X/Z)")
            
        return int(dut.result.value)

    # Test Case 1: Simple flip (matches sample logic scaled)
    # Input: [8, 8, 2, -2] -> Logic needs flips
    # Scaled to 16 items, we'll fill rest with 0s (0 is tricky, usually needs removal or flip)
    # Let's try a simple alternating sequence: 1, -1, 1, -1
    # Cost should be 0
    scores1 = [1, -1, 1, -1] + [0] * 12
    res1 = await run_test(scores1, 10, 50)
    exp1 = 0
    if res1 != exp1:
        raise TestFailure(f"TC1: Expected {exp1}, got {res1}")

    # Test Case 2: Need flips
    # [1, 1] -> Flip second to -1. Cost = C
    scores2 = [1, 1] + [0] * 14
    res2 = await run_test(scores2, 10, 50)
    exp2 = 10
    if res2 != exp2:
        raise TestFailure(f"TC2: Expected {exp2}, got {res2}")

    # Test Case 3: Need removal
    # [0, 0] -> Must remove (0 cannot be signed non-zero). Cost = R + R
    # Or flip both then remove? No, 0 -> 1 or -1 costs C. But removing is R.
    # If R < 2*C, remove is better. 50 < 20, so remove is cheaper? No, 50 > 20.
    # Wait, 0 needs to be non-zero. 0 -> 1 (cost C). Sequence [1, 1] invalid.
    # So 0 -> 1, 0 -> -1 (cost 2C). Or Remove, Remove (cost 2R).
    # Let's use C=100, R=10 to force removal.
    scores3 = [0, 0] + [0] * 14
    res3 = await run_test(scores3, 100, 10)
    exp3 = 20  # 2 removals * 10 = 20
    if res3 != exp3:
        raise TestFailure(f"TC3: Expected {exp3}, got {res3}")

    # Test Case 4: Mixed
    # [5, 5, 5] -> Needs 2 flips (5, -5, 5) or 2 removals (5) or 1 flip 1 removal.
    # C=10, R=50. Flip 2 = 20. Remove 2 = 100. Remove 1 Flip 1 = 60.
    # Best is 2 flips.
    scores4 = [5, 5, 5] + [0] * 13
    res4 = await run_test(scores4, 10, 50)
    exp4 = 20
    if res4 != exp4:
        raise TestFailure(f"TC4: Expected {exp4}, got {res4}")

    cocotb.log.info(f"All tests passed!")