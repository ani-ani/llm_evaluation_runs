import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_unique_product(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    await RisingEdge(dut.clk)
    await Timer(10, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # Test 1: 10 not included in scaled case (needs 5 bits)
        {"data": [5, 10, 5, 15], "expected": 5*10*15}, 
        # Original Test 2
        {"data": [1, 2, 3, 1], "expected": 6},
        # Original Test 3 modified
        {"data": [7, 1, 0, 1], "expected": 0},
        # Edge case: all duplicates
        {"data": [5, 5, 5, 5], "expected": 5},
        # Edge case: max unique
        {"data": [0,1,2,3,4,5,6,7], "expected": 0}
    ]

    passed = 0
    for case in test_cases:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed data
        for num in case["data"]:
            dut.data_valid.value = 1
            dut.data_in.value = num
            await RisingEdge(dut.clk)
        dut.data_valid.value = 0
        
        # Wait for calculation
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if int(dut.product.value) == case["expected"]:
            passed += 1
            dut._log.info(f"PASS: {case['data']} => {case['expected']}")
        else:
            dut._log.error(f"FAIL: {case['data']} => {int(dut.product.value)} (expected {case['expected']})")
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)