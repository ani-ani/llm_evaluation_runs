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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Precompute primes up to 31 for testing
PRIMES = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31]

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_frog_tower(dut):
    # Setup clock
    clk_gen = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clk_gen.start())
    
    await reset_dut(dut)
    
    # Test Cases
    # Case 1: 3 frogs, expected pos 3, size 2
    # Frog 0: pos 0, dist 2 -> hits 0, 2, 4...
    # Frog 1: pos 1, dist 2 -> hits 1, 3, 5...
    # Frog 2: pos 3, dist 3 -> hits 3, 6, 9...
    # At pos 3: Frog 1 and 2 meet.
    test_cases = [
        {"frogs": [(0, 2), (1, 2), (3, 3)], "expected_pos": 3, "expected_size": 2},
        # Case 2: 5 frogs
        # (0,2), (1,3), (3,3), (7,5), (9,5)
        # (0,2) hits: 0,2,4,6,8,10,12...
        # (1,3) hits: 1,4,7,10,13...
        # (3,3) hits: 3,6,9,12,15...
        # (7,5) hits: 7,12,17...
        # (9,5) hits: 9,14,19...
        # At pos 12: (0,2), (3,3), (7,5) meet. Size 3.
        {"frogs": [(0, 2), (1, 3), (3, 3), (7, 5), (9, 5)], "expected_pos": 12, "expected_size": 3},
        # Case 3: Edge case small
        {"frogs": [(5, 2), (5, 3)], "expected_pos": 5, "expected_size": 2},
        # Case 4: No overlap until later
        {"frogs": [(0, 5), (1, 3)], "expected_pos": 10, "expected_size": 2},
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        frogs = tc["frogs"]
        num_frogs = len(frogs)
        
        # Set inputs
        if has_signal(dut, 'num_frogs'):
            dut.num_frogs.value = num_frogs
        
        # Set arrays
        for j in range(8): # Max 8 frogs
            # Defaults to 0 if not set
            p = frogs[j][0] if j < num_frogs else 0
            d = frogs[j][1] if j < num_frogs else 2
            
            # Array access: dut.frog_pos[j].value = ...
            if has_signal(dut, f'frog_pos_{j}'):
                getattr(dut, f'frog_pos_{j}').value = clamp_to_width(p, 8)
                getattr(dut, f'frog_dist_{j}').value = clamp_to_width(d, 5)
            elif hasattr(dut, 'frog_pos'):
                # Fallback if packed array (unlikely but safe)
                pass
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read results
        if has_signal(dut, 'result_pos'):
            pos = int(dut.result_pos.value)
        else:
            pos = 0
            
        if has_signal(dut, 'result_size'):
            size = int(dut.result_size.value)
        else:
            size = 0
            
        exp_pos = tc["expected_pos"]
        exp_size = tc["expected_size"]
        
        cocotb.log.info(f"Result: Pos={pos}, Size={size} | Expected: Pos={exp_pos}, Size={exp_size}")
        
        if pos != exp_pos or size != exp_size:
            raise TestFailure(f"Test {i+1} Failed: Got ({pos}, {size}), Expected ({exp_pos}, {exp_size})")
        
        # Reset for next test
        await reset_dut(dut)

