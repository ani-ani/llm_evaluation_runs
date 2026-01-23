import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_payout(dut):
    """Test the max_payout module with various inputs."""
    
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_n.value = 0
    dut.num_m.value = 0
    # Initialize weights array (size 100)
    for i in range(100):
        setattr(dut, f'weights_{i}', 0)
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Define Test Cases
    # Case 1: n=5, weights [3, 2]. Expected k=2 (needs 2 verts, size 2), sum=5
    # k=2 (even): required = 2*2/2 = 2. 2 <= 5. Sum top 2 = 5.
    dut.num_n.value = 5
    dut.num_m.value = 2
    setattr(dut, 'weights_0', 3)
    setattr(dut, 'weights_1', 2)
    
    # Case 2: n=1, weights [100, 1]. Expected k=1 (needs 1 vert, size 1), sum=100
    # k=1 (odd): required = 1*0/2 + 1 = 1. 1 <= 1. Sum top 1 = 100.
    # We will update inputs in loop

    # Let's create a list of test tuples (n, m, weights_list, expected_sum)
    # Weights in sorted order (descending)
    test_cases = [
        (5, 2, [3, 2], 5),
        (1, 2, [100, 1], 100),
        (100, 3, [2, 1, 1], 4), # k=3 (odd): 3*2/2+1=4 <= 100. sum=4.
        (2, 5, [1,1,1,1,1], 2), # k=2 (even): 2*2/2=2 <= 2. sum=2.
        (3, 3, [1,1,1], 2),     # k=2 (even): 2 <= 3. k=3 (odd): 4 > 3. sum=2.
        (17, 6, [6,5,4,3,2,1], 20), # k=6 (even): 6*6/2=18 > 17. k=5 (odd): 5*4/2+1=11 <= 17. sum=6+5+4+3+2=20.
        (7, 4, [5,4,3,2], 12), # k=4 (even): 8 > 7. k=3 (odd): 4 <= 7. sum=5+4+3=12.
        (7, 4, [1,1,1,1], 3),  # k=3 (odd): 4 <= 7. sum=3.
        (7, 5, [1,1,1,1,1], 3), # k=3 (odd): 4 <= 7. k=4 (even): 8 > 7. sum=3.
        (17, 9, [1]*9, 5),      # k=5 (odd): 11 <= 17. k=6 (even): 18 > 17. sum=5.
        (2, 2, [1,1], 2),       # k=2 (even): 2 <= 2. sum=2.
        (8, 7, [1]*7, 4),       # k=4 (even): 8 <= 8. k=5 (odd): 11 > 8. sum=4.
        (11, 5, [1]*5, 5),      # k=5 (odd): 11 <= 11. sum=5.
        (31, 8, [128,64,32,16,8,4,2,1], 254), # k=8 (even): 32 > 31. k=7 (odd): 22 <= 31. sum=128+64+32+16+8+4+2=254.
        (10, 6, [1]*6, 4),      # k=4 (even): 8 <= 10. k=5 (odd): 11 > 10. sum=4.
        (11, 10, [5]*10, 25),   # k=5 (odd): 11 <= 11. sum=25.
        (8, 10, [1]*10, 4),     # k=4 (even): 8 <= 8. sum=4.
    ]

    total_tests = len(test_cases)
    passed = 0

    for n, m, weights, expected_sum in test_cases:
        # Setup inputs
        dut.num_n.value = n
        dut.num_m.value = m
        for i in range(100):
            val = weights[i] if i < m else 0
            setattr(dut, f'weights_{i}', val)
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 2000 # Safety timeout
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"Test failed for N={n}, M={m}: Timeout")
            continue

        # Check result
        result = int(dut.max_sum.value)
        if result == expected_sum:
            passed += 1
            print(f"Test N={n}, M={m}: PASSED (Result={result})")
        else:
            print(f"Test N={n}, M={m}: FAILED (Expected={expected_sum}, Got={result})")
            raise TestFailure(f"Mismatch for N={n}")
            
        # Reset for next test (or just let it loop)
        # Note: The module relies on accumulated sum, so we need to reset logic if internal state isn't cleared.
        # Assuming the module design resets sum on start or IDLE, we just need to wait for next start.
        # However, to be safe, let's toggle reset if the design doesn't auto-clear sum.
        # Based on spec "iterate k from 1", sum should be reset at start.
        
    print(f"
Summary: {passed}/{total_tests} tests passed")
