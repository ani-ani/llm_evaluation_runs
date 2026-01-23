import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure, TestSuccess

@cocotb.test()
async def test_garbage_disposal(dut):
    """Test the garbage_disposal module with various inputs"""
    
    # Create a clock with 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_i.value = 0
    dut.n.value = 0
    dut.k.value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases (n, k, list_of_garbage, expected_bags)
    test_cases = [
        (3, 2, [3, 2, 1], 3),
        (3, 2, [1, 0, 1], 2),
        (4, 4, [2, 8, 4, 1], 4),
        (1, 1, [0], 0),
        (1, 1, [1], 1),
        (4, 5, [5, 5, 5, 5], 4),
        (3, 2, [1, 0, 0], 1),
        (2, 3, [2, 7], 3),
        (3, 6, [2, 3, 3], 2),
        (4, 4, [3, 6, 2, 3], 4)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, k, garbage_list, expected in test_cases:
        # Reset for new test case logic (pulse reset)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        
        # Set parameters
        dut.n.value = n
        dut.k.value = k
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed garbage data and check processing
        # We need to feed data as the state machine requests it.
        # Based on the prompt, we have a_i as input. The DUT is expected to latch it or read it.
        # We will simulate by driving a_i on the cycle corresponding to the day.
        
        day = 0
        done_flag = False
        
        # Run for n + 5 cycles (enough for processing + done)
        for cycle in range(n + 10):
            await RisingEdge(dut.clk)
            
            # Check if done
            if dut.done.value == 1 and not done_flag:
                done_flag = True
                result = int(dut.total_bags.value)
                if result == expected:
                    passed += 1
                    print(f"CASE n={n}, k={k}, arr={garbage_list}: PASS (Got {result})")
                else:
                    print(f"CASE n={n}, k={k}, arr={garbage_list}: FAIL (Got {result}, Expected {expected})")
                break
            
            # Drive a_i if we are in the processing phase
            # We assume the module accepts a_i whenever it is processing a day
            # The day_index output tells us which day the module is currently handling
            current_day = int(dut.day_index.value)
            if current_day < n and dut.done.value == 0:
                # If the module hasn't finished, feed the current day's garbage
                # Note: We drive a_i continuously based on day_index for this simple testbench
                dut.a_i.value = garbage_list[current_day]
            else:
                dut.a_i.value = 0

    print(f"
SUMMARY: {passed}/{total} tests passed")
    if passed == total:
        raise TestSuccess("All tests passed!")
    else:
        raise TestFailure(f"{total - passed} tests failed.")