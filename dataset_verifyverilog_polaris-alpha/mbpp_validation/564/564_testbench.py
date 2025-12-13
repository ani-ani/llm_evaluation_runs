import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_pair_counter(dut):
    # Generate clock (100MHz)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        dut.size.value = 0
        for i in range(8):
            dut.arr[i].value = 0
        await RisingEdge(dut.clk)
    
    test_cases = [
        {'size': 3, 'arr': [1,2,1,0,0,0,0,0], 'expected': 2},
        {'size': 4, 'arr': [1,1,1,1,0,0,0,0], 'expected': 0},
        {'size': 5, 'arr': [1,2,3,4,5,0,0,0], 'expected': 10},
        {'size': 2, 'arr': [8,8,0,0,0,0,0,0], 'expected': 0},
        {'size': 8, 'arr': [1,2,3,1,2,3,1,2], 'expected': 24}
    ]
    
    passed = 0
    total = len(test_cases)
    
    await reset()
    
    for case in test_cases:
        # Load test case
        dut.size.value = case['size']
        for i in range(8):
            dut.arr[i].value = case['arr'][i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify result
        if dut.count.value == case['expected']:
            passed += 1
            dut._log.info(f"PASS: Size={case['size']}, Count={dut.count.value}")
        else:
            dut._log.error(f"FAIL: Size={case['size']}, Got {dut.count.value}, Expected {case['expected']}")
        
        await RisingEdge(dut.clk)
        await reset()
    
    dut._log.info(f"{passed}/{total} tests passed")