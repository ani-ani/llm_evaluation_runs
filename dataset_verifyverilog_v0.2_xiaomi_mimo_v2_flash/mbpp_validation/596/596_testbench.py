import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_tuple_size(dut):
    """Test tuple_size module with various tuple configurations"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    for i in range(8):
        dut.element_widths[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (num_elements, element_widths_list, expected_result)
        (6, [2, 1, 2, 1, 2, 1, 0, 0], 32),  # Test 1: 6 elements, widths 2,1,2,1,2,1 => 9+20=29... wait
        # Actually let me recalculate:
        # Test 1: ("A", 1, "B", 2, "C", 3) 
        # "A"=1 char, 1=int(4), "B"=1, 2=int(4), "C"=1, 3=int(4) => 1+4+1+4+1+4 = 15 + 20 = 35
        # But simplified: assume all 2 bytes except ints are 4
        # Let's use simplified representation: strings=2 bytes, ints=4 bytes
        # Test 1: 3 strings + 3 ints => 3*2 + 3*4 = 6+12=18 + 20 = 38
        # Test 2: same pattern
        # Test 3: 4 nested tuples => each 4 bytes => 16 + 20 = 36
        
        # Simplified test cases based on module spec:
        (6, [2, 4, 2, 4, 2, 4, 0, 0], 38),  # Test 1: 6 elements, mixed widths
        (6, [4, 2, 4, 2, 4, 2, 0, 0], 38),  # Test 2: 6 elements, different order
        (4, [4, 4, 4, 4, 0, 0, 0, 0], 36),  # Test 3: 4 elements, all 4 bytes
        (0, [0, 0, 0, 0, 0, 0, 0, 0], 20),  # Edge case: empty tuple
        (1, [10, 0, 0, 0, 0, 0, 0, 0], 30),  # Edge case: single large element (capped at 4? no, spec says 1-4, so use 4)
        (8, [1, 1, 1, 1, 1, 1, 1, 1], 28),  # Edge case: 8 elements of 1 byte each
    ]
    
    # Correction: spec says element_widths are 1-4 bytes. Let's adjust test cases to be valid
    # element_widths input is [7:0] so up to 255, but we assume user provides valid 1-4
    # Let's recompute with our formula: sum + 20
    
    adjusted_test_cases = [
        # Test 1: 6 elements => [2, 2, 2, 2, 2, 2] if all chars, or mixed
        # Let's assume test case uses: 2,2,2,2,2,2 = 12 + 20 = 32  
        (6, [2, 2, 2, 2, 2, 2, 0, 0], 32),
        # Test 2: 6 elements, mixed => [2, 4, 2, 4, 2, 4] = 18 + 20 = 38
        (6, [2, 4, 2, 4, 2, 4, 0, 0], 38),
        # Test 3: 4 nested tuples => each 4 bytes => 16 + 20 = 36
        (4, [4, 4, 4, 4, 0, 0, 0, 0], 36),
        # Edge: empty
        (0, [0, 0, 0, 0, 0, 0, 0, 0], 20),
        # Edge: max elements with min width
        (8, [1, 1, 1, 1, 1, 1, 1, 1], 28),
        # Edge: single element, max width
        (1, [4, 0, 0, 0, 0, 0, 0, 0], 24),
    ]
    
    passed = 0
    total = len(adjusted_test_cases)
    
    for num_elem, widths, expected in adjusted_test_cases:
        # Load inputs
        dut.num_elements.value = num_elem
        for i in range(8):
            dut.element_widths[i].value = widths[i]
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (should take 8 cycles + 1 for IDLE transition)
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.done.value != 1:
            raise TestFailure(f"Done not asserted for case: num={num_elem}, widths={widths}")
        
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: num={num_elem}, widths={widths}, expected={expected}, got={actual}")
        else:
            raise TestFailure(f"FAIL: num={num_elem}, widths={widths}, expected={expected}, got={actual}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} of {total} tests passed"
