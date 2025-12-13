import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_rectangle_overlap(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await Timer(15, units='ns')
    
    test_cases = [
        {
            'n': 3, 
            'rects': [(0,0,1,1), (1,1,2,2), (3,0,4,1)],
            'expected': (1,1)
        },
        {
            'n': 3,
            'rects': [(0,0,1,1), (0,1,1,2), (1,0,2,1)],
            'expected': (1,1)
        },
        {
            'n': 4,
            'rects': [(0,0,5,5), (0,0,4,4), (1,1,4,4), (1,1,4,4)],
            'expected': (1,1)
        },
        {
            'n': 5,
            'rects': [(0,0,10,8), (1,2,6,7), (2,3,5,6), (3,4,4,5), (8,1,9,2)],
            'expected': (3,4)
        },
        {
            'n': 2,
            'rects': [(-1,-1,0,0), (0,0,1,1)],
            'expected': (0,0)
        }
    ]
    passed = 0
    total = len(test_cases)
    for case in test_cases:
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        dut.n.value = case['n']
        for i in range(8):
            dut.rect_x1[i].value = 0
            dut.rect_y1[i].value = 0
            dut.rect_x2[i].value = 0
            dut.rect_y2[i].value = 0
        
        for i in range(case['n']):
            x1, y1, x2, y2 = case['rects'][i]
            dut.rect_x1[i].value = x1
            dut.rect_y1[i].value = y1
            dut.rect_x2[i].value = x2
            dut.rect_y2[i].value = y2
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        timeout = 20
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
            
        if timeout <= 0:
            raise TestFailure("Test timed out waiting for done")
            
        x_val = dut.point_x.value.signed_integer
        y_val = dut.point_y.value.signed_integer
        exp_x, exp_y = case['expected']
        if x_val == exp_x and y_val == exp_y:
            passed += 1
        else:
            dut._log.error("Test failed: Got (%d, %d), expected (%d, %d)" % (x_val, y_val, exp_x, exp_y))
    dut._log.info("%d/%d tests passed" % (passed, total))