import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_warlord(dut):
    # Test cases (scaled to 8 warlords/8 lines)
    tests = [
        # Input: W, N, [line0...line7], expected_k
        (2, 1, [
            [1,1,-2,0], [0,0,0,0],[0,0,0,0],[0,0,0,0],
            [0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]], 0),  # Original sample 1
        (5, 3, [
            [0,5,5,5], [0,0,1,1], [2,2,3,3], [0,0,0,0],
            [0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]], 1),  # Original sample 2
        (8, 2, [
            [0,0,1,0], [0,0,1,1], [0,0,0,0],[0,0,0,0],
            [0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]], 3)  # Needs 3 more lines (R=4)
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for (warlords, n_lines, lines, expected_k) in tests:
        dut.W.value = warlords
        dut.N_lines.value = n_lines
        # Load all 8 lines (unused are zeroed)
        for i in range(8):
            dut.lines[i][0].value = lines[i][0]
            dut.lines[i][1].value = lines[i][1]
            dut.lines[i][2].value = lines[i][2]
            dut.lines[i][3].value = lines[i][3]
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 8 cycles (+1 for reset alignment)
        for _ in range(9):
            await RisingEdge(dut.clk)
        
        if dut.done.value != 1:
            await RisingEdge(dut.done)  # Extra wait if needed
        
        result = dut.k.value
        if int(result) == expected_k:
            passed += 1
        else:
            dut._log.error("For W=%d N=%d lines: Got %d, Expected %d" % 
                          (warlords, n_lines, int(result), expected_k))
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("%d/%d tests passed" % (passed, len(tests)))