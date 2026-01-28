import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

# Constants based on scaled problem
MAX_N = 64
MAX_T = 512
DATA_WIDTH = 16

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_dog_bowls(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(20, units='ns')
        dut.rst_n.value = 1
    
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    # Test cases: (n, T_limit, t_arr, expected)
    test_cases = [
        (3, 5, [1, 5, 3], 2),
        (1, 2, [1], 1),
        (1, 1, [1], 0),
        (1, 1, [2], 0),
        (2, 2, [2, 3], 0),
        (2, 3, [2, 1], 1),
        (3, 3, [2, 3, 2], 1),
        (3, 2, [2, 3, 4], 0),
        (3, 4, [2, 1, 2], 2),
        (4, 4, [2, 1, 2, 3], 2),
        (4, 3, [2, 1, 2, 3], 1),
        (4, 6, [2, 3, 4, 5], 4),
    ]

    passed = 0
    failed = 0

    for i, (n, T_limit, t_arr, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: n={n}, T={T_limit}, t={t_arr}")
        
        # Check if signals exist before writing
        if not (has_signal(dut, 'n') and has_signal(dut, 'T_limit') and has_signal(dut, 't_arr')):
            cocotb.log.error("Required signals (n, T_limit, t_arr) not found in DUT")
            failed += 1
            continue

        # Write inputs
        dut.n.value = n
        dut.T_limit.value = T_limit
        
        # Write t_arr (assuming unpacked array or packed logic)
        # Assuming unpacked array t_arr[0:63]
        for idx in range(MAX_N):
            if idx < len(t_arr):
                val = clamp_to_width(t_arr[idx], DATA_WIDTH)
                dut.t_arr[idx].value = val
            else:
                dut.t_arr[idx].value = 0
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            dut.start.value = 0
        else:
            # If no start signal, assume inputs are latched on clock edge
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')

        # Wait for done
        if has_signal(dut, 'done'):
            done = False
            for _ in range(200): # Max cycles for N=64
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(10, units='ns')
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                cocotb.log.error(f"Test {i+1} Failed: Timeout waiting for done")
                failed += 1
                continue
        else:
            # Combinational logic, wait a bit
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(100, units='ns')

        # Read result
        if has_signal(dut, 'result'):
            result_val = int(dut.result.value)
            if result_val == expected:
                cocotb.log.info(f"Test {i+1} Passed: Got {result_val}")
                passed += 1
            else:
                cocotb.log.error(f"Test {i+1} Failed: Expected {expected}, Got {result_val}")
                failed += 1
        else:
            cocotb.log.error("Result signal not found")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
