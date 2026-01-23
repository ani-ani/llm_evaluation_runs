import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_bamboo_solver(dut):
    """Test the bamboo solver with various inputs."""
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.stop.value = 0
    dut.a_0.value = 0
    dut.a_1.value = 0
    dut.a_2.value = 0
    dut.a_3.value = 0
    dut.k.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to calculate expected waste
    def calc_waste(a, d):
        if d == 0: return 0
        cut_height = d * ((a + d - 1) // d)
        return cut_height - a
    
    def find_max_d(a_list, k_max):
        best = 1
        for d in range(1, 4096):
            total = 0
            for a in a_list:
                total += calc_waste(a, d)
            if total <= k_max:
                best = d
        return best

    # Test cases (scaled down from original)
    test_vectors = [
        ([1, 3, 5, 0], 4, "Example 1 scaled"),
        ([10, 30, 50, 0], 40, "Example 2 scaled"),
        ([100, 100, 100, 100], 500, "All same"),
        ([255, 255, 255, 255], 1000, "Max values"),
        ([1, 1, 1, 1], 0, "Min waste"),
        ([50, 100, 150, 200], 200, "Mixed")
    ]
    
    passed = 0
    total = len(test_vectors)
    
    for a_vec, k_val, name in test_vectors:
        # Setup inputs
        dut.a_0.value = a_vec[0]
        dut.a_1.value = a_vec[1]
        dut.a_2.value = a_vec[2]
        dut.a_3.value = a_vec[3]
        dut.k.value = k_val
        
        # Calculate expected using Python
        expected_best = find_max_d(a_vec, k_val)
        
        # Start operation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Let it run for enough cycles to find max d (or use stop)
        # We let it run for 500 cycles or until done
        cycles = 0
        while cycles < 500:
            await RisingEdge(dut.clk)
            cycles += 1
            # We can force stop if we want to verify intermediate state,
            # but here we let it run or check done signal if implemented.
            # The spec says 'stop' input stops search. Let's use it at the end.
            if cycles > 4100: 
                dut.stop.value = 1
            if dut.done.value == 1:
                break
        
        # Read result
        result = int(dut.best_d.value)
        
        if result == expected_best:
            dut._log.info(f"Test '{name}' Passed: d={result} (Expected {expected_best})")
            passed += 1
        else:
            dut._log.error(f"Test '{name}' Failed: d={result} (Expected {expected_best})")
            # Debug print
            dut._log.error(f"Inputs: A={a_vec}, k={k_val}")

    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, "Some tests failed"
