import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_subset_subsets(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test cases: (n, k, coins, expected_xs)
    test_cases = [
        (6, 18, [5, 6, 1, 10, 12, 2], [0,1,2,3,5,6,7,8,10,11,12,13,15,16,17,18]),
        (3, 50, [25, 25, 50], [0, 25, 50]),
        (1, 1, [1], [0, 1]),
    ]

    for tc_idx, (n, k, coins, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {tc_idx+1}: n={n}, k={k}, coins={coins}")
        
        # Load inputs
        dut.n_in.value = n
        dut.k_in.value = k
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Provide coins sequentially
        for i in range(n):
            dut.coin_i.value = coins[i]
            await RisingEdge(dut.clk)
            # Check if processing started (optional, but good for debug)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Verify results
        if not is_value_defined(dut.result_count.value):
            raise TestFailure(f"Test {tc_idx+1}: result_count undefined")
            
        count = int(dut.result_count.value)
        if count != len(expected):
            raise TestFailure(f"Test {tc_idx+1}: Expected {len(expected)} values, got {count}")
        
        # Read results
        actual = []
        for i in range(count):
            val_name = f"result_x_{i}"
            if has_signal(dut, val_name):
                val = int(getattr(dut, val_name).value)
                actual.append(val)
            else:
                # If array port: dut.result_x[i]
                val = int(dut.result_x[i].value)
                actual.append(val)
                
        actual.sort()
        if actual != expected:
            raise TestFailure(f"Test {tc_idx+1}: Expected {expected}, got {actual}")
            
        cocotb.log.info(f"Test {tc_idx+1} PASSED")
        
        # Reset for next test
        await reset_dut(dut)