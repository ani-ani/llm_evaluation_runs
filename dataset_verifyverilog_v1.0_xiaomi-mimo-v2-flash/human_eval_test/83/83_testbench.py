import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 100

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

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_starts_one_ends(dut):
    """Test the starts_one_ends module"""
    
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 1
        if has_start:
            dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Reset if needed
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    # Test cases from the problem
    test_cases = [
        (1, 1, "n=1"),
        (2, 18, "n=2"),
        (3, 180, "n=3"),
        (4, 1800, "n=4"),
        (5, 18000, "n=5"),
        (0, 0, "n=0 edge case"),
        (6, 0, "n=6 out of range"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n}, expected={expected})")
        
        try:
            # Set input n
            dut.n.value = clamp_to_width(n, 3)
            
            if is_seq and has_start:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                if has_done:
                    for _ in range(MAX_CYCLES):
                        await RisingEdge(dut.clk)
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            break
                    else:
                        raise TestFailure(f"Timeout waiting for done")
            else:
                await Timer(10, units='ns')  # Combinational settle time
            
            # Read result
            if not has_signal(dut, 'count'):
                raise TestFailure(f"Missing 'count' output")
            
            if not is_value_defined(dut.count.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.count.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
    
    # Additional edge case tests
    additional_tests = [
        (1, 1),
        (2, 18),
        (3, 180),
        (4, 1800),
        (5, 18000),
    ]
    
    # Random tests for n in valid range
    for _ in range(10):
        n = random.randint(1, 5)
        if n == 1:
            expected = 1
        else:
            expected = 18 * (10 ** (n - 2))
        additional_tests.append((n, expected))
    
    for n, expected in additional_tests:
        dut.n.value = clamp_to_width(n, 3)
        await Timer(10, units='ns')
        result = int(dut.count.value) if is_value_defined(dut.count.value) else 0
        if result != expected:
            cocotb.log.error(f"Additional test failed: n={n}, expected={expected}, got={result}")
            failed += 1
        else:
            passed += 1
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    
    if failed:
        raise TestFailure(f"{failed} tests failed")