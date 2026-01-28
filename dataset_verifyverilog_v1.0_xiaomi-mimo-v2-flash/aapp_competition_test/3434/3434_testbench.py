import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    val = int(v)
    max_val = (1 << bits) - 1
    return min(max_val, max(0, val))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Fixed point helpers
FRAC_BITS = 16
SCALE = 1 << FRAC_BITS

def float_to_fixed(f):
    return int(f * SCALE)

def fixed_to_float(v):
    return v / SCALE

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=50000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=60, timeout_unit="s")
async def test_explosion_probability(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units="ns")
        cocotb.start_soon(clock.start())
    else:
        # Combinational test
        pass

    await reset_dut(dut)

    # Test Cases based on problem examples
    test_cases = [
        {
            "n": 1, "m": 2, "d": 2,
            "my_health": [2, 0, 0, 0, 0],
            "opp_health": [1, 1, 0, 0, 0],
            "expected_prob": 0.3333333333
        },
        {
            "n": 2, "m": 3, "d": 12,
            "my_health": [3, 2, 0, 0, 0],
            "opp_health": [4, 2, 3, 0, 0],
            "expected_prob": 0.1377380946
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        # Load inputs
        # Assuming inputs are arrays of signals like my_health_0, my_health_1...
        # Or a packed array. We will try to handle both or individual signals.
        
        # We need to populate the health values into the DUT
        for idx in range(5):
            if has_signal(dut, f'my_health_{idx}'):
                getattr(dut, f'my_health_{idx}').value = clamp_to_width(tc['my_health'][idx], 4)
            elif has_signal(dut, f'my_health') and hasattr(dut.my_health, '__len__'):
                dut.my_health[idx].value = clamp_to_width(tc['my_health'][idx], 4)
        
        for idx in range(5):
            if has_signal(dut, f'opp_health_{idx}'):
                getattr(dut, f'opp_health_{idx}').value = clamp_to_width(tc['opp_health'][idx], 4)
            elif has_signal(dut, f'opp_health') and hasattr(dut.opp_health, '__len__'):
                dut.opp_health[idx].value = clamp_to_width(tc['opp_health'][idx], 4)

        if has_signal(dut, 'd'):
            dut.d.value = clamp_to_width(tc['d'], 7)

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if has_signal(dut, 'result'):
            # Assuming result is 32-bit fixed point
            result_val = int(dut.result.value)
            result_float = fixed_to_float(result_val)
            
            # Check relative error or absolute error
            error = abs(result_float - tc['expected_prob'])
            
            cocotb.log.info(f"Result: {result_float}, Expected: {tc['expected_prob']}, Error: {error}")
            
            if error > 1e-4: # Using slightly relaxed tolerance for fixed point
                raise TestFailure(f"Test {i+1} failed. Expected {tc['expected_prob']}, got {result_float}")
        else:
            raise TestFailure("Result signal not found")