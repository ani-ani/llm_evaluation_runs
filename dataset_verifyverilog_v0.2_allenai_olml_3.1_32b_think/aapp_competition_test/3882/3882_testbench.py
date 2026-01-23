import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

# Reference answers for n=1 to 8 (from Python sequence 1, 3, 10, 37, 151, 674, 3263, 17007)
ref_results = {1: 1, 2: 3, 3: 10, 4: 37, 5: 151, 6: 674, 7: 3263, 8: 17007}

@cocotb.test()
async def test_sym_trans_count(dut):
    """Test the symmetric transitive count module"""
    
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test all valid inputs
    tests_passed = 0
    tests_total = 0
    
    for n_val in range(1, 9):
        tests_total += 1
        
        # Start computation
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 100
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        expected = ref_results[n_val]
        
        if actual == expected:
            tests_passed += 1
            dut._log.info(f"n={n_val}: PASS (Result={actual})")
        else:
            dut._log.error(f"n={n_val}: FAIL (Expected={expected}, Got={actual})")
    
    # Test edge case n=0 (should handle gracefully or return 0)
    tests_total += 1
    dut.n.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(100):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    actual = int(dut.result.value)
    # For n=0, expected behavior is undefined in problem, but let's see. 
    # The table recurrence A[0][0]=1. If we query A[0][-1] it's invalid. 
    # We assume input is 1-8. Let's just print.
    dut._log.info(f"n=0: Result={actual}")
    
    print(f"Summary: {tests_passed}/{tests_total} tests passed")
    assert tests_passed == tests_total
