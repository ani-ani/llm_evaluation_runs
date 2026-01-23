import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_shuttle_optimizer(dut):
    """Test the shuttle optimizer module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 11 people, 2 cars from problem statement
    # Expected output: 13500 seconds
    n1 = 11
    k1 = 2
    times1 = [12000, 9000, 4500, 10000, 12000, 11000, 12000, 18000, 10000, 9000, 12000]
    expected1 = 13500
    
    # Test case 2: 6 people, 2 cars
    # Expected output: 2000 seconds
    n2 = 6
    k2 = 2
    times2 = [1000, 2000, 3000, 4000, 5000, 6000]
    expected2 = 2000
    
    # Test case 3: Single car, single person
    n3 = 1
    k3 = 1
    times3 = [5000]
    expected3 = 5000
    
    # Test case 4: All in one trip (n <= 5*k)
    n4 = 10
    k4 = 3
    times4 = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
    expected4 = 1000
    
    test_cases = [
        (n1, k1, times1, expected1),
        (n2, k2, times2, expected2),
        (n3, k3, times3, expected3),
        (n4, k4, times4, expected4)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (n, k, times, expected) in enumerate(test_cases):
        print(f"
Running test case {i+1}: n={n}, k={k}")
        
        # Load inputs
        dut.n_in.value = n
        dut.k_in.value = k
        
        # Pad times array and convert to Q16.16
        for j in range(16):
            if j < n:
                # Convert to Q16.16: value * 65536
                dut.t_in[j].value = int(times[j] * 65536)
            else:
                dut.t_in[j].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 500 cycles for worst case)
        timeout = 500
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            print(f"Timeout for test case {i+1}")
            continue
        
        # Read result
        result_raw = dut.min_time.value
        result_seconds = result_raw / 65536.0
        
        print(f"Expected: {expected} seconds")
        print(f"Got: {result_seconds:.2f} seconds (raw: {result_raw})")
        
        # Allow small rounding error (0.1 seconds)
        if abs(result_seconds - expected) < 0.1:
            passed += 1
            print(f"Test case {i+1} PASSED")
        else:
            print(f"Test case {i+1} FAILED")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"
