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
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Recursive function to generate all subsequences and sort them lexicographically
def generate_all_subsequences(arr):
    n = len(arr)
    subs = []
    # Iterate over all non-empty masks
    for mask in range(1, 1 << n):
        sub = []
        for i in range(n):
            if mask & (1 << i):
                sub.append(arr[i])
        subs.append(sub)
    
    # Sort lexicographically
    # Python's default list comparison is lexicographic
    subs.sort()
    return subs

def calculate_hash(sub, B, M):
    if not sub:
        return 0
    val = 0
    for x in sub:
        val = (val * B + x) % M
    return val

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_subsequence_hash(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case from examples
    # Example 1: N=2, K=3, B=1, M=5, Arr=[1, 2]
    N = 2
    K = 3
    B = 1
    M = 5
    arr = [1, 2]

    dut.K.value = K
    dut.B.value = B
    dut.M.value = M
    
    # Set array elements
    # Assuming interface arr_0, arr_1... or arr[0], arr[1]
    # We check for packed array or individual signals
    if has_signal(dut, 'arr_0'):
        for i in range(N):
            getattr(dut, f'arr_{i}').value = arr[i]
    elif has_signal(dut, 'arr'):
        # Assuming packed array or array of signals
        # We try to access by index if possible (Verilog unpacked array in sim)
        for i in range(N):
            try:
                dut.arr[i].value = arr[i]
            except Exception:
                # Fallback if it's a single large bus
                pass
    
    # Generate expected results
    subs = generate_all_subsequences(arr)
    expected_hashes = []
    for sub in subs[:K]:
        h = calculate_hash(sub, B, M)
        expected_hashes.append(h)
    
    cocotb.log.info(f"Expected hashes: {expected_hashes}")

    # Start generation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for outputs
    results = []
    timeout = 2000  # cycles
    
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'valid') and int(dut.valid.value) == 1:
            # Read hash
            h = int(dut.hash_out.value)
            results.append(h)
            cocotb.log.info(f"Received hash: {h}")
            if len(results) == K:
                break
        
        if has_signal(dut, 'done') and int(dut.done.value) == 1:
            # Check if we have all results
            if len(results) < K:
                # Maybe valid was low on last cycle, check now
                if has_signal(dut, 'valid') and int(dut.valid.value) == 1:
                     h = int(dut.hash_out.value)
                     results.append(h)
            break
    
    # Verify results
    if len(results) != K:
        raise TestFailure(f"Expected {K} hashes, got {len(results)}")
    
    for i, (got, exp) in enumerate(zip(results, expected_hashes)):
        if got != exp:
            raise TestFailure(f"Hash {i}: Expected {exp}, got {got}")

    cocotb.log.info("Test passed!")
