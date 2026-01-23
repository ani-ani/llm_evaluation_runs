import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
import random

# Helper to count ones in range using Python logic (ground truth)
def python_solution(n, l, r):
    # Helper to get length of sequence for n
    def get_len(x):
        if x <= 1:
            return 1
        return 2 * get_len(x // 2) + 1
    
    # Recursive function to count 1s in range [ql, qr] (1-based)
    def count_rec(n, ql, qr, total_len):
        if ql > qr:
            return 0
        if n <= 1:
            return n if (ql <= 1 <= qr) else 0
            
        mid = get_len(n // 2) + 1
        
        # If range is entirely in left part
        if qr < mid:
            return count_rec(n // 2, ql, qr, mid - 1)
        # If range is entirely in right part
        elif ql > mid:
            return count_rec(n // 2, ql - mid, qr - mid, mid - 1)
        # Range spans multiple parts
        else:
            total = 0
            # Left part overlap
            if ql < mid:
                total += count_rec(n // 2, ql, mid - 1, mid - 1)
            # Middle element
            if ql <= mid <= qr:
                total += n % 2
            # Right part overlap
            if qr > mid:
                total += count_rec(n // 2, 1, qr - mid, mid - 1)
            return total
            
    return count_rec(n, l, r, get_len(n))

@cocotb.test()
async def test_count_ones_range(dut):
    """Test count_ones_range module with various inputs"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_in.value = 0
    dut.l_in.value = 0
    dut.r_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, l, r)
    # We scale inputs to fit 16-bit n and 14-bit l/r constraints
    # Max length for n=16383 is approx 32767
    test_cases = [
        (7, 2, 5),       # Original example
        (10, 3, 10),     # Original example
        (15, 1, 7),      # n=15 (1111) -> sequence of 1s
        (4, 1, 5),       # n=4 (100) -> sequence 1 0 1 0 1
        (56, 18, 40),    # Scaled large case
        (0, 1, 1),       # Edge case: n=0
        (1, 1, 1),       # Edge case: n=1
        (2, 2, 2),       # n=2 -> sequence 1 0 1
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, l, r in test_cases:
        # Scale down if necessary to fit bits (for this testbench, we use the values directly)
        # Note: The module is designed for 16-bit n, 14-bit l/r.
        # The testbench will just feed values. Simulation might fail if Python result is huge.
        # However, for small tests, it works.
        
        # Check if inputs fit module constraints
        if n > 65535 or l > 16383 or r > 16383:
            print(f"Skipping {n}, {l}, {r} (out of bounds for module)")
            total -= 1
            continue

        # Calculate expected result
        try:
            expected = python_solution(n, l, r)
        except RecursionError:
            print(f"Skipping {n}, {l}, {r} (Python recursion depth)")
            total -= 1
            continue

        # Drive inputs
        dut.n_in.value = n
        dut.l_in.value = l
        dut.r_in.value = r
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 50000: # Safeguard
                break
        
        # Read result
        actual = int(dut.result.value)
        
        print(f"Input: n={n}, l={l}, r={r}")
        print(f"Expected: {expected}, Actual: {actual}")
        
        if actual == expected:
            passed += 1
        else:
            print(f"FAILED: n={n}, l={l}, r={r}")
        
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"