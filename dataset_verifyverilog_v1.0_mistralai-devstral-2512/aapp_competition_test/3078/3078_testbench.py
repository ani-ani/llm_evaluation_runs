import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
N_MAX = 16
S_MAX = 65535
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def reset_signal(dut, name):
    if has_signal(dut, name):
        setattr(dut, name, 0)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Reference Python implementation for test cases
def solve_interesting_subsequence(arr, n, s):
    results = []
    for i in range(n):
        max_len = 0
        # Check all possible even lengths starting from i
        # Max length is 2*K where 2*K <= n-i
        for k in range(1, (n - i) // 2 + 1):
            length = 2 * k
            # Sum first K
            sum1 = sum(arr[i:i+k])
            # Sum last K
            sum2 = sum(arr[i+k:i+2*k])
            if sum1 <= s and sum2 <= s:
                if length > max_len:
                    max_len = length
        results.append(max_len)
    return results

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_interesting_subsequence(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem statement (scaled down)
    test_cases = [
        {
            "name": "Example 1 (5 elements)",
            "arr": [1, 1, 1, 1, 1],
            "n": 5,
            "s": 10000,
            "expected": [4, 4, 2, 2, 0]
        },
        {
            "name": "Example 2 (5 elements)",
            "arr": [1, 1, 10, 1, 9],
            "n": 5,
            "s": 9,
            "expected": [2, 0, 0, 2, 0]
        },
        {
            "name": "Example 3 (8 elements)",
            "arr": [1, 1, 1, 1, 1, 1, 1, 1],
            "n": 8,
            "s": 3,
            "expected": [6, 6, 6, 4, 4, 2, 2, 0]
        },
        {
            "name": "Single element (edge case)",
            "arr": [5],
            "n": 1,
            "s": 10,
            "expected": [0]  # No even length possible
        },
        {
            "name": "All zeros",
            "arr": [0, 0, 0, 0],
            "n": 4,
            "s": 5,
            "expected": [4, 4, 0, 0]
        }
    ]

    passed = 0
    failed = 0

    for test in test_cases:
        arr = test["arr"]
        n = test["n"]
        s = test["s"]
        expected = test["expected"]
        name = test["name"]

        cocotb.log.info(f"\n=== Testing: {name} ===")
        cocotb.log.info(f"Input: N={n}, S={s}, Array={arr}")

        # Skip if N > 16 (hardware constraint)
        if n > N_MAX:
            cocotb.log.warning(f"Skipping {name}: N={n} > {N_MAX} (HW constraint)")
            continue

        # Reset for each test case
        if is_seq:
            await reset_dut(dut)

        # Write inputs
        for i in range(N_MAX):
            val = clamp_to_width(arr[i] if i < n else 0, DATA_WIDTH)
            if has_signal(dut, f'A_{i}'):
                getattr(dut, f'A_{i}').value = val
            elif has_signal(dut, 'A'):
                dut.A[i].value = val
            else:
                # Fallback for packed array (unlikely but handled)
                pass

        # Write N and S
        if has_signal(dut, 'N'):
            dut.N.value = clamp_to_width(n, 4)
        if has_signal(dut, 'S'):
            dut.S.value = clamp_to_width(s, DATA_WIDTH)

        # Start calculation
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            await Timer(100, units='ns')

        # Collect results sequentially
        actual_results = []
        if is_seq:
            # Wait for results to be output
            # Expected number of results = n
            for idx in range(n):
                # Wait for result_valid or timeout
                valid_found = False
                for _ in range(100):  # Wait up to 100 cycles per result
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                        valid_found = True
                        break
                
                if not valid_found:
                    raise TestFailure(f"Timeout waiting for result for index {idx}")
                
                # Read result
                res_idx = safe_int(dut.result_index.value)
                res_len = safe_int(dut.result_length.value)
                
                # Verify index matches expected
                if res_idx != idx:
                    cocotb.log.warning(f"Result index mismatch: expected {idx}, got {res_idx}")
                
                actual_results.append(res_len)
                cocotb.log.info(f"  Index {res_idx}: Length = {res_len}")

            # Wait for done signal
            await wait_for_done(dut)
        
        # Compare results
        if len(actual_results) != len(expected):
            cocotb.log.error(f"Result count mismatch: expected {len(expected)}, got {len(actual_results)}")
            failed += 1
            continue

        test_passed = True
        for i, (actual, exp) in enumerate(zip(actual_results, expected)):
            if actual != exp:
                cocotb.log.error(f"  Index {i}: Expected {exp}, got {actual}")
                test_passed = False
        
        if test_passed:
            cocotb.log.info(f"PASS: {name}")
            passed += 1
        else:
            cocotb.log.error(f"FAIL: {name}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
