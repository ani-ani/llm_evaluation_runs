import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def compute_original_ring(b_values, N):
    """Python reference implementation for verification"""
    a = [0] * N
    a[0] = 0
    a[1] = b_values[0] - a[0]
    for i in range(1, N-1):
        a[i+1] = b_values[i] - a[i] - a[i-1]
    
    # Check closure
    computed_b7 = a[N-2] + a[N-1] + a[0]
    actual_b7 = b_values[N-1]
    diff = computed_b7 - actual_b7
    
    if N % 2 == 1:  # Odd
        # Should be diff == 0
        if diff != 0:
            return None  # Should not happen
        return a
    else:  # Even
        # Need to adjust
        k = diff // (N // 2)
        if diff % (N // 2) != 0:
            return None
        for i in range(N):
            if i % 2 == 0:
                a[i] += k
            else:
                a[i] -= k
        # Verify all non-negative
        if any(x < 0 for x in a):
            return None
        return a

@cocotb.test()
async def test_ring_reconstruct(dut):
    """Test ring reconstruction module"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_count.value = 0
    for i in range(8):
        dut._id(f"b{i}", False).value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (N, b_values, expected_a_values)
        (3, [5, 5, 5], [2, 1, 2]),
        (4, [20, 15, 17, 14], [5, 8, 2, 7]),
        (5, [7, 8, 9, 10, 11], [4, 1, 3, 5, 2]),
        (6, [30, 20, 25, 22, 28, 24], [10, 5, 12, 3, 14, 15]),
        (8, [50, 40, 45, 42, 48, 46, 52, 44], [20, 10, 25, 5, 30, 1, 35, 9]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, b_vals, expected_a in test_cases:
        print(f"
Test N={n}: b={b_vals}")
        
        # Compute reference
        ref_a = compute_original_ring(b_vals, n)
        if ref_a is None:
            print(f"  Warning: Reference computation failed, using expected {expected_a}")
            ref_a = expected_a
        
        # Set inputs
        dut.valid_count.value = n
        dut.b0.value = b_vals[0]
        dut.b1.value = b_vals[1] if n > 1 else 0
        dut.b2.value = b_vals[2] if n > 2 else 0
        dut.b3.value = b_vals[3] if n > 3 else 0
        dut.b4.value = b_vals[4] if n > 4 else 0
        dut.b5.value = b_vals[5] if n > 5 else 0
        dut.b6.value = b_vals[6] if n > 6 else 0
        dut.b7.value = b_vals[7] if n > 7 else 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (15 cycles + some margin)
        max_wait = 20
        for _ in range(max_wait):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Module did not complete for N={n}")
        
        # Check done and error
        if dut.error.value == 1:
            print(f"  Error flag set, skipping check")
            continue
        
        # Read outputs
        out_a = [
            int(dut.a0.value),
            int(dut.a1.value),
            int(dut.a2.value),
            int(dut.a3.value),
            int(dut.a4.value),
            int(dut.a5.value),
            int(dut.a6.value),
            int(dut.a7.value),
        ][:n]
        
        print(f"  Output: {out_a}")
        print(f"  Expected: {ref_a}")
        
        # Verify
        if out_a == ref_a:
            passed += 1
            print(f"  PASSED")
        else:
            # Also check if it's a valid alternative solution
            # Verify ring condition: b[i] = a[i-1] + a[i] + a[i+1]
            valid = True
            for i in range(n):
                prev = out_a[(i-1) % n]
                curr = out_a[i]
                next_val = out_a[(i+1) % n]
                if prev + curr + next_val != b_vals[i]:
                    valid = False
                    break
            
            if valid and all(x >= 0 for x in out_a):
                # Also check rotation constraint
                if out_a[0] == ref_a[0]:  # First element must match
                    passed += 1
                    print(f"  PASSED (valid alternative solution)")
                else:
                    print(f"  FAILED (rotation mismatch)")
            else:
                print(f"  FAILED")
                print(f"    Valid: {valid}, Non-negative: {all(x >= 0 for x in out_a)}")
    
    print(f"
{passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
