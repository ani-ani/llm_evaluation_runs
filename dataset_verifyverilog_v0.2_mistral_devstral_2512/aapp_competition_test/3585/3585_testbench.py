import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_bag_capacity(dut):
    """Test bag_capacity module with various m and k values"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.m.value = 0
    dut.k.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (m, k, expected_result)
    # Scaled values fitting m <= 8, k <= 4
    # Formula: (2*m + 1)^k
    test_cases = [
        (0, 0, 1),      # 1^0 = 1
        (0, 1, 1),      # 1^1 = 1
        (1, 0, 1),      # 3^0 = 1
        (1, 1, 3),      # 3^1 = 3
        (1, 2, 9),      # 3^2 = 9
        (2, 1, 5),      # 5^1 = 5
        (2, 2, 25),     # 5^2 = 25
        (3, 1, 7),      # 7^1 = 7
        (4, 1, 9),      # 9^1 = 9
        (8, 4, 83521),  # 17^4 = 83521
    ]
    
    passed = 0
    total = len(test_cases)
    
    for m_val, k_val, expected in test_cases:
        # Input values
        dut.m.value = m_val
        dut.k.value = k_val
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
            dut._log.info(f"Test passed: m={m_val}, k={k_val}, result={actual}")
        else:
            dut._log.error(f"Test failed: m={m_val}, k={k_val}, expected={expected}, got={actual}")
        
        await RisingEdge(dut.clk)
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"