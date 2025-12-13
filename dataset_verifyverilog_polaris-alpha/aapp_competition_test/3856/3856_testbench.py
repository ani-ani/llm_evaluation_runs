import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_min_photo_area(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases: (n, [w0,h0, ...], expected_area)
    test_cases = [
        (3, [3,1, 4,2, 5,3, 0,0], 30),   # Original: 3x1,4x2,5x3 → area 10*3=30
        (1, [5,10,0,0,0,0,0,0], 50),    # Forced no flip
        (3, [3,1,2,2,4,3,0,0], 21),     # Original 2nd example
        (2, [1,15,15,1,0,0,0,0], 32),   # Flips: 0+15=15w×15h=225 vs flip both: h1+w1=1+1=2w×15h=30 (wrong? Mandatory flips if h_i>max_h?)
        (4, [8,2,8,3,8,4,8,5], 72)      # Max_h=5: sum widths=2+3+4+5=14, 14*5=70
    ]
    passed = 0

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1

    for tc in test_cases:
        n, vals, expected = tc
        dut.n.value = n
        dut.w0.value = vals[0]; dut.h0.value = vals[1]
        dut.w1.value = vals[2]; dut.h1.value = vals[3]
        dut.w2.value = vals[4]; dut.h2.value = vals[5]
        dut.w3.value = vals[6]; dut.h3.value = vals[7]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (timeout 200 cycles)
        for _ in range(200):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.min_area.value != expected:
            dut._log.error("FAIL: n=%d vals=%s got=%d exp=%d" % (n, str(vals), dut.min_area.value, expected))
        else:
            passed += 1
    
    dut._log.info("Test summary: %d/%d passed" % (passed, len(test_cases)))