import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_jacobsthal(dut):
    """Test Jacobsthal number computation for n=0 to n=15"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Expected Jacobsthal numbers for n=0 to 15
    expected = [0, 1, 1, 3, 5, 11, 21, 43, 85, 171, 341, 683, 1365, 2731, 5461, 10923]
    
    passed = 0
    total = len(expected)
    
    for n, exp_val in enumerate(expected):
        # Load n and start
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 50  # prevent infinite loop
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        # Read result
        actual = int(dut.result.value)
        
        # Verify
        assert actual == exp_val, f"n={n}: expected {exp_val}, got {actual}"
        passed += 1
        print(f"Test n={n}: PASSED (result={actual})")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Some tests failed: {passed}/{total} passed"

@cocotb.test()
async def test_jacobsthal_edge_cases(dut):
    """Test edge cases and verify state transitions"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test n=0 (base case)
    dut.n.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)  # Should complete quickly
    assert dut.done.value == 1, "Should be done for n=0"
    assert int(dut.result.value) == 0, "J(0) should be 0"
    print("Edge case n=0: PASSED")
    
    await RisingEdge(dut.clk)
    
    # Test n=1 (base case)
    dut.n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    assert dut.done.value == 1, "Should be done for n=1"
    assert int(dut.result.value) == 1, "J(1) should be 1"
    print("Edge case n=1: PASSED")
    
    await RisingEdge(dut.clk)
    
    # Test n=13 (original test case value)
    dut.n.value = 13
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (should take ~13 cycles)
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert int(dut.result.value) == 2731, "J(13) should be 2731"
    print("Edge case n=13: PASSED")
    
    print("
=== All edge case tests passed ===")
}