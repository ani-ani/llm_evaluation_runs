import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_even_odd_count(dut):
    """Test even_odd_count module with various integers"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input, expected_even, expected_odd)
    test_cases = [
        (7, 0, 1),           # (0, 1)
        (-78, 1, 1),         # (1, 1)
        (3452, 2, 2),        # (2, 2)
        (346211, 3, 3),      # (3, 3)
        (-345821, 3, 3),     # (3, 3)
        (-2, 1, 0),          # (1, 0)
        (-45347, 2, 3),      # (2, 3)
        (0, 1, 0),           # (1, 0)
    ]
    
    total_tests = len(test_cases)
    passed_tests = 0
    
    for num_val, exp_even, exp_odd in test_cases:
        # Set input
        dut.num.value = num_val
        await RisingEdge(dut.clk)
        
        # Assert start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 15 cycles for safety)
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for num={num_val}")
        
        # Check results
        even = int(dut.even_count.value)
        odd = int(dut.odd_count.value)
        
        if even == exp_even and odd == exp_odd:
            passed_tests += 1
            dut._log.info(f"PASS: num={num_val}, even={even}, odd={odd}")
        else:
            dut._log.error(f"FAIL: num={num_val}, expected ({exp_even}, {exp_odd}), got ({even}, {odd})")
    
    dut._log.info(f"
{passed_tests}/{total_tests} tests passed")
    assert passed_tests == total_tests, f"Only {passed_tests}/{total_tests} tests passed"
