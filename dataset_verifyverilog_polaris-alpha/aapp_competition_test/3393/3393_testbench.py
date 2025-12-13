import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_course_optimizer(dut):
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset()
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test cases (n=5,k=2 sum=20; n=7,k=5 sum=360)
    test_cases = [
        (
            5, 2,
            [10, 10, 20, 50, 100, 0,0,0],  // difficulties
            [1,1,0,1,0,0,0,0],            // is_level1 (idx1,2,3)
            [0,0,1,0,1,0,0,0],            // is_level2 (idx2,4)
            [0,1,1,2,2,0,0,0],            // pair_id (calc:1,2; honors:3,4)
            20  // Expected sum
        ),
        (
            7, 5,
            [40,50,200,120,200,100,50,0],
            [0,1,0,0,0,1,0,0],
            [0,0,1,0,0,0,1,0],
            [0,1,1,0,0,2,2,0],
            360
        )
    ]

    await reset()
    passed = 0
    total = len(test_cases)

    for n, k, diffs, l1, l2, pairs, expected in test_cases:
        # Load inputs
        dut.n.value = n
        dut.k.value = k
        for i in range(8):
            dut.difficulties[i].value = diffs[i]
            dut.is_level1[i].value = l1[i]
            dut.is_level2[i].value = l2[i]
            dut.pair_id[i].value = pairs[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (16 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
                
        # Check result
        if dut.min_sum.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d k=%d expected=%d got=%d" % 
                          (n, k, expected, dut.min_sum.value))
    
    dut._log.info("%d/%d tests passed" % (passed, total))"