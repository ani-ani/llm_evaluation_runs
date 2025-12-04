import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_cake_checker(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled to 8 candles max, 4 cuts max)
    test_cases = [
        # Sample 1 (4 candles, 2 cuts)
        {
            "n": 4, "m": 2, "r": 3,
            "candles": [(0,1), (1,0), (-1,0), (0,-1)],
            "cuts": [(-1,1,0), (2,1,0)],
            "expected": 1
        },
        # Sample 2 (4 candles, 3 cuts)
        {
            "n": 4, "m": 3, "r": 3,
            "candles": [(0,1), (1,2), (-1,2), (0,-1)],
            "cuts": [(-1,1,-2), (-1,-1,2), (0,-1,0)],
            "expected": 0
        },
        # Sample 3 (3 candles, 2 cuts)
        {
            "n": 3, "m": 2, "r": 3,
            "candles": [(2,1), (0,0), (-1,-2)],
            "cuts": [(1,1,-2), (3,6,12)],
            "expected": 1
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = case["n"]
        dut.m.value = case["m"]
        dut.r.value = case["r"]
        
        for i in range(8):
            if i < len(case["candles"]):
                dut.candle_x[i].value = case["candles"][i][0]
                dut.candle_y[i].value = case["candles"][i][1]
            else:
                dut.candle_x[i].value = 0
                dut.candle_y[i].value = 0
        
        for i in range(4):
            if i < len(case["cuts"]):
                dut.cut_a[i].value = case["cuts"][i][0]
                dut.cut_b[i].value = case["cuts"][i][1]
                dut.cut_c[i].value = case["cuts"][i][2]
            else:
                dut.cut_a[i].value = 0
                dut.cut_b[i].value = 0
                dut.cut_c[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (25 cycles)
        for _ in range(25):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        if dut.result.value == case["expected"]:
            passed += 1
        else:
            dut._log.error("Test failed: Expected %d got %d", case["expected"], dut.result.value)
    
    dut._log.info("%d/%d tests passed", passed, total)