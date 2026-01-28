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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_delete_columns(dut):
    # Configuration for small N=16 test
    N_MAX = 16
    DATA_WIDTH = 4
    CLK_NS = 10
    
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    else:
        await Timer(CLK_NS, units='ns')

    # Test Cases (scaled for N=16)
    # Case 1: N=3 (Values 1-3), columns to keep: 3 (cols 0,2,4 example logic)
    # Original Input: 
    # 5 4 3 2 1 6 7
    # 5 5 1 1 3 4 7
    # 3 7 1 4 5 6 2
    # Mapping 1-3 for N=3 or just use small N=5 example
    
    test_sets = [
        {
            "N": 5,
            "row0": [5, 4, 3, 2, 1],
            "row1": [5, 5, 1, 1, 3],
            "row2": [3, 7, 1, 4, 5], # Note: 7 is > N, clipping to 5 or handling as invalid is required? 
                                       # Constraint says 1 to N. For test, we will stick to valid 1-N values.
            "expected_del": 2 # Keep 5, 3, 1 (indices 0, 2, 4) -> 5,3,1 sorted. 
                              # Row 1: 5,1,3 sorted. Row 2: 3,1,5 sorted. Matches.
        },
        {
            "N": 4,
            "row0": [1, 2, 3, 4],
            "row1": [1, 1, 1, 1],
            "row2": [1, 2, 3, 4],
            "expected_del": 3 # Keep only index 0 (value 1) or any single 1 in row 1 is valid? 
                               # Row 0: 1. Row 1: 1. Row 2: 1. Yes.
        }
    ]

    for i, case in enumerate(test_sets):
        dut._log.info(f"Running Test Case {i+1}")
        N = case["N"]
        r0 = case["row0"]
        r1 = case["row1"]
        r2 = case["row2"]
        
        # Write inputs
        # Check if inputs are arrays or individual signals
        if has_signal(dut, 'N'):
            dut.N.value = N
        
        # Helper to write arrays
        def write_row(row_name, values):
            # Check for array-like access (dut.row0) vs indexed (dut.row0_0)
            try:
                arr_sig = getattr(dut, row_name)
                if hasattr(arr_sig, '__len__'):
                    # It's an array of signals
                    for idx in range(min(len(values), N_MAX)):
                        arr_sig[idx].value = clamp_to_width(values[idx], DATA_WIDTH)
                else:
                    # Single signal? Unlikely for row input
                    pass
            except AttributeError:
                # Try indexed names row0_0, row0_1...
                for idx in range(min(len(values), N_MAX)):
                    sig_name = f"{row_name}_{idx}"
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = clamp_to_width(values[idx], DATA_WIDTH)

        write_row('row0', r0)
        write_row('row1', r1)
        write_row('row2', r2)

        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
            dut.start.value = 0
        
        # Wait for done
        timeout = 2000 # cycles
        if has_signal(dut, 'done'):
            for _ in range(timeout):
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(CLK_NS, units='ns')
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done signal")
        else:
            # Combinational logic simulation delay
            await Timer(2000, units='ns')

        # Read result
        if has_signal(dut, 'min_deletions'):
            result = int(dut.min_deletions.value)
            dut._log.info(f"Result: {result}, Expected: {case['expected_del']}")
            if result != case['expected_del']:
                raise TestFailure(f"Test {i+1} Failed: Expected {case['expected_del']}, got {result}")
        else:
            raise TestFailure("Output signal 'min_deletions' not found")
