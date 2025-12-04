import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def stone_pile_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = {
        3: [3,5,7,0,0,0,0,0],
        4: [4,6,8,10,0,0,0,0],
        5: [5,7,9,11,13,0,0,0],
        6: [6,8,10,12,14,16,0,0],
        8: [8,10,12,14,16,18,20,22]
    }
    
    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for n_val, expected in test_cases.items():
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        for _ in range(15):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        error = False
        for i in range(8):
            actual = dut.levels[i].value.integer
            if i < n_val:
                if actual != expected[i]:
                    dut._log.error(f"FAIL n={n_val} level[{i}]: {actual} != {expected[i]}")
                    error = True
            else:
                # Check unused elements are zero (reset state)
                if actual != 0:
                    dut._log.error(f"FAIL n={n_val} level[{i}] not reset: {actual} != 0")
                    error = True
        
        if not error:
            passed += 1
            dut._log.info(f"PASS: n={n_val}")
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"TESTS PASSED: {passed}/{len(test_cases)}")
    assert passed == len(test_cases)