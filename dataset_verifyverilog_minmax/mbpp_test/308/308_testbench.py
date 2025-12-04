import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_top_n(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (list1, list2, N, expected_top_N)
    test_cases = [
        ([1,2,3,4,5,6], [3,6,8,9,10,6], 3, [60,54,50]),
        ([1,2,3,4,5,6], [3,6,8,9,10,6], 4, [60,54,50,48]),
        ([1,2,3,4,5,6], [3,6,8,9,10,6], 5, [60,54,50,48,45])
    ]

    passed = 0

    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for case in test_cases:
        list1, list2, N_value, expected = case
        
        # Load inputs
        for i in range(6):
            dut.list1[i].value = list1[i]
            dut.list2[i].value = list2[i]
        dut.N.value = N_value
        dut.start.value = 1

        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Verify outputs
        success = True
        for i in range(N_value):
            if dut.products[i].value != expected[i]:
                success = False
                dut._log.error(f"Mismatch at index {i}: Got {dut.products[i].value}, Expected {expected[i]}")

        if success:
            passed += 1
            dut._log.info(f"PASSED for N={N_value}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
