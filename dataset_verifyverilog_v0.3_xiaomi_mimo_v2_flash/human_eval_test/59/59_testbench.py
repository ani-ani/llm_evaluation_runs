import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_largest_prime_factor(dut):
    """Test largest_prime_factor module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    clock.start()
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_n, expected_result)
    test_cases = [
        (15, 5),
        (27, 3),
        (63, 7),
        (330, 11),
        (13195, 29),
        (2048, 2),
        (10, 5),
        (17, 17) # Prime input (though problem says n is not prime, good to handle)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_n, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: n={input_n}, expected={expected}")
        
        # Set input and start signal
        dut.n.value = input_n
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        max_cycles = 2000
        completed = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                completed = True
                break
        
        if not completed:
            raise TestFailure(f"Test {i+1} timeout after {max_cycles} cycles")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: result undefined")
        
        actual = int(dut.result.value)
        
        if actual != expected:
            raise TestFailure(f"Test {i+1}: n={input_n}, expected {expected}, got {actual}")
        
        dut._log.info(f"Test {i+1}: PASSED")
        passed += 1
        
        await Timer(50, units='ns')
    
    dut._log.info(f"\nTest Summary: {passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
