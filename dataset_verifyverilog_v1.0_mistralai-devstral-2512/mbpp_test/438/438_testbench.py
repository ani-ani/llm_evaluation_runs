import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_tuple(dut, idx, a, b, data_width=8):
    """Load a single tuple into the dut at index idx"""
    if has_signal(dut, f'arr_{idx}_a'):
        getattr(dut, f'arr_{idx}_a').value = clamp_to_width(a, data_width)
    if has_signal(dut, f'arr_{idx}_b'):
        getattr(dut, f'arr_{idx}_b').value = clamp_to_width(b, data_width)

async def load_tuples(dut, tuples, num_tuples, data_width=8):
    """Load all tuples and set num_tuples"""
    for idx, (a, b) in enumerate(tuples):
        await load_tuple(dut, idx, a, b, data_width)
    if has_signal(dut, 'num_tuples'):
        dut.num_tuples.value = clamp_to_width(num_tuples, 4)
    else:
        # For designs with fixed array size
        for idx in range(len(tuples), 8):
            await load_tuple(dut, idx, 0, 0, data_width)

async def compute_bidirectional(dut, tuples):
    """Run the bidirectional counter computation"""
    num_tuples = len(tuples)
    
    # Load inputs
    await load_tuples(dut, tuples, num_tuples)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read result
    result = int(dut.result.value) if is_value_defined(dut.result.value) else 0
    return result

# Manual count function for verification
def count_bidirectional(tuples):
    """Python reference implementation"""
    res = 0
    n = len(tuples)
    for j in range(n):
        for i in range(j + 1, n):
            if tuples[i][0] == tuples[j][1] and tuples[j][0] == tuples[i][1]:
                res += 1
    return res

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bidirectional_counter(dut):
    """Test bidirectional tuple pair counter"""
    
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Test cases
    test_cases = [
        ([(5, 6), (1, 2), (6, 5), (9, 1), (6, 5), (2, 1)], 3, "Test 1: 3 pairs"),
        ([(5, 6), (1, 3), (6, 5), (9, 1), (6, 5), (2, 1)], 2, "Test 2: 2 pairs"),
        ([(5, 6), (1, 2), (6, 5), (9, 2), (6, 5), (2, 1)], 4, "Test 3: 4 pairs"),
    ]
    
    # Additional edge cases
    edge_cases = [
        ([], 0, "Empty array"),
        ([(1, 2)], 0, "Single tuple"),
        ([(1, 2), (2, 1)], 1, "One pair only"),
        ([(1, 2), (2, 1), (1, 2)], 2, "Duplicate tuple"),
        ([(0, 0), (0, 0), (0, 0)], 3, "Zero pairs (identical)"),  # (0,0) is its own reverse
    ]
    
    all_cases = test_cases + edge_cases
    
    passed = 0
    failed = 0
    
    for i, (tuples, expected, desc) in enumerate(all_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            result = await compute_bidirectional(dut, tuples)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result} for {tuples}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {result} == {expected}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            # Continue with other tests
    
    # Additional performance test: verify it handles max arrays
    max_tuples = [(i, 7-i) for i in range(8)]  # 8 tuples
    max_expected = count_bidirectional(max_tuples)
    cocotb.log.info(f"Test MAX: 8 tuples")
    try:
        result = await compute_bidirectional(dut, max_tuples)
        if result != max_expected:
            raise TestFailure(f"Max test failed: Expected {max_expected}, got {result}")
        passed += 1
        cocotb.log.info(f"  PASS: {result} == {max_expected}")
    except TestFailure as e:
        cocotb.log.error(f"  FAIL: {e}")
        failed += 1
    
    # Summary
    total = passed + failed
    cocotb.log.info(f"\n=== Summary ===")
    cocotb.log.info(f"Passed: {passed}/{total}")
    cocotb.log.info(f"Failed: {failed}/{total}")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {total} tests failed")
    
    return passed, failed

# Quick test runner for local verification
if __name__ == "__main__":
    print("Testing reference implementation...")
    test_cases = [
        ([(5, 6), (1, 2), (6, 5), (9, 1), (6, 5), (2, 1)], 3),
        ([(5, 6), (1, 3), (6, 5), (9, 1), (6, 5), (2, 1)], 2),
        ([(5, 6), (1, 2), (6, 5), (9, 2), (6, 5), (2, 1)], 4),
    ]
    for i, (tuples, expected) in enumerate(test_cases, 1):
        result = count_bidirectional(tuples)
        status = "PASS" if result == expected else "FAIL"
        print(f"Test {i}: {status} (got {result}, expected {expected})")