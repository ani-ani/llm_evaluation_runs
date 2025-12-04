import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_lunch_bill(dut):
    # Create clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (37, [8, 9, 11, 15], 4),  # Sample Input 1 (truncated outputs)
        (100, [10], 1),           # Simple case B=10, M=90
        (20, [], 0)               # No valid pairs (test edge)
    ]
    
    passed = 0
    for P_value, expected_Bs, expected_count in test_cases:
        dut._log.info(f"Testing P={P_value}")
        # Setup P input
        dut.P.value = P_value
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Capture outputs
        results = []
        while (not dut.done.value):
            await RisingEdge(dut.clk)
            if dut.valid.value:
                B = int(dut.B_out.value)
                M = int(dut.M_out.value)
                results.append((B, M))
        
        # Verify count and pairs
        actual_count = int(dut.count.value)
        valid_Bs = [b for b, m in results]
        
        # Check count matches
        if actual_count != expected_count:
            dut._log.error(f"Count mismatch: {actual_count} vs expected {expected_count}")
        # Check each B value matches
        elif all(b in expected_Bs for b in valid_Bs) and sorted(valid_Bs) == sorted(expected_Bs):
            passed += 1
        else:
            dut._log.error(f"Data mismatch: {valid_Bs} vs expected {expected_Bs}")
        
        # Reset before next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} passed")
    assert passed == len(test_cases)