import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_optimal_sub(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (adapted to 16-bit max)
    tests = [
        # Original scaled tests
        {"k":1, "data":0b01, "exp_idx":2, "exp_len":1}, #
        {"k":4, "data":0b01100110, "exp_idx":2, "exp_len":6}, # 0110011 → last 6 bits
        # New edge cases
        {"k":2, "data":0b1111_0000_1111_0000, "exp_idx":1, "exp_len":4}, # first 4 ones
        {"k":3, "data":0b1100_1100_1100_1100, "exp_idx":1, "exp_len":16} # whole string (tie breaker)
    ]
    
    passed = 0
    for test in tests:
        # Apply test inputs
        dut.k.value = test["k"]
        dut.data.value = test["data"]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation to finish (max 16 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        # Check outputs
        if not dut.done.value:
            dut._log.error("Timeout waiting for done")
        
        idx = dut.first_idx.value.integer
        l = dut.length.value.integer
        exp_idx = test["exp_idx"]
        exp_len = test["exp_len"]
        
        if idx == exp_idx and l == exp_len:
            passed += 1
        else:
            dut._log.error(f"FAIL: k={test['k']} data={bin(test['data'])} got ({idx},{l}) expected ({exp_idx},{exp_len})")
    
    dut._log.info(f"{passed}/{len(tests)} tests passed")
    assert passed == len(tests)