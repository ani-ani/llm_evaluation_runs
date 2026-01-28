import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 4  # 4-bit per switch/light
ARRAY_SIZE = 4  # Max n = 4
MAX_PHOTOS = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_config(configs, element_bits=4):
    """Pack list of photo configs into single integer."""
    result = 0
    for i, photo in enumerate(configs):
        for j, bit in enumerate(photo):
            if bit == '1':
                result |= 1 << (i * element_bits + j)
    return result

def factorial(n):
    if n <= 1:
        return 1
    result = 1
    for i in range(2, n + 1):
        result *= i
    return result

# Helper: Generate all permutations (Python) for verification
def generate_permutations(n):
    """Generate all permutations of [0..n-1]."""
    from itertools import permutations
    return list(permutations(range(n)))

def check_permutation(switches, lights, perm):
    """Check if a permutation is consistent with photo."""
    for i in range(len(switches)):
        if switches[i] != lights[perm[i]]:
            return False
    return True

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_wiring_counter(dut):
    """Test wiring counter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (n, m, switch_strings, light_strings, expected_result)
        (
            3, 1,
            ["110"],
            ["011"],
            2
        ),
        (
            4, 2,
            ["1000", "0000"],
            ["1000", "0010"],
            0
        ),
        (
            1, 1,
            ["1"],
            ["1"],
            1
        ),
        (
            2, 1,
            ["10"],
            ["01"],
            2
        ),
        (
            2, 0,
            [],
            [],
            2  # 2! = 2
        ),
        (
            3, 0,
            [],
            [],
            6  # 3! = 6
        ),
        (
            4, 0,
            [],
            [],
            24  # 4! = 24
        ),
        (
            3, 1,
            ["111"],
            ["111"],
            6  # All permutations work
        ),
        (
            3, 1,
            ["111"],
            ["000"],
            0  # Impossible (all switches on but no lights on)
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, m, switch_strs, light_strs, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: n={n}, m={m}")
        
        # Pack configurations
        switch_config = pack_config(switch_strs) if m > 0 else 0
        light_config = pack_config(light_strs) if m > 0 else 0
        
        cocotb.log.info(f"  Switch config: {switch_config:08x}")
        cocotb.log.info(f"  Light config:  {light_config:08x}")
        cocotb.log.info(f"  Expected: {expected}")
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        dut.switch_config.value = switch_config
        dut.light_config.value = light_config
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = MAX_CYCLES
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            timeout -= 1
            if timeout == 0:
                raise TestFailure(f"Timeout waiting for done in test {test_idx + 1}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined in test {test_idx + 1}")
        
        result = int(dut.result.value)
        cocotb.log.info(f"  Result: {result}")
        
        if result == expected:
            cocotb.log.info(f"  PASS")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
