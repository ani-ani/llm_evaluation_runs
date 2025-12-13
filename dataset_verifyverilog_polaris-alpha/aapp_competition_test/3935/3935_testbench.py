import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_eraser(dut):
    # Test cases (scaled from original)
    test_cases = [
        # Input: 3 elements [1,2,3] (exponents:0,1,0) erase 2
        {'input': [1,  2, 3, 0,0,0,0,0], 'expect_count':1, 'expect_erased':[2,0,0,0,0,0,0,0]},
        # Input: 2 elements [2,6] (exponents:1,1) no erase
        {'input': [2, 6, 0,0,0,0,0,0], 'expect_count':0, 'expect_erased':[0,0,0,0,0,0,0,0]},
        # Input: 16 becomes [16,32,64] - keeping exponent 5 group
        {'input': [16,32,64,8,4,2,1,48], 'expect_count':5, 'expect_erased':[8,4,2,1,48,0,0,0]}
    ]
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz clock
    cocotb.start_soon(clock.start())
    passed = 0
    for test in test_cases:
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        dut.data_in.value = 0
        await RisingEdge(dut.clk)
        # Load inputs
        for i in range(8):
            dut.data_in.value = test['input'][i]
            dut.start.value = (i == 0) # Start on first element
            await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for processing (max 16 cycles)
        timeout = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            timeout +=1
            if timeout > 30:
                assert False, "Timeout waiting for done"
        # Check erased count
        assert dut.erased_count.value == test['expect_count'], "Erased count mismatch"
        # Verify erased elements
        err = False
        for i in range(8):
            if i < test['expect_count']:
                assert dut.element_valid.value == 1, "element_valid not high"
                observed = dut.erased_element.value
                expected = test['expect_erased'][i]
                if observed != expected:
                    dut._log.error(f"Element {i} wrong: {observed} != {expected}")
                    err = True
            await RisingEdge(dut.clk)
        if not err:
            passed +=1
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
