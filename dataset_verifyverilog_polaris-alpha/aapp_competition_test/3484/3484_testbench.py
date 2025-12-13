import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_superdoku(dut):
    # Create 10MHz clock
    clock = Clock(dut.clk, 100, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset system
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_data = [
        {'k': 2, 'grid': [1,2,3,4,2,3,4,1,0,0,0,0,0,0,0,0], 'valid': 1, 
            'expect_grid': [1,2,3,4,2,3,4,1,3,4,1,2,4,1,2,3]},
        {'k': 2, 'grid': [1,2,3,4,2,2,2,2,0,0,0,0,0,0,0,0], 'valid': 0}
    ]
    passed = 0
    
    for test in test_data:
        # Flatten grid to 32-bit input
        grid_in = 0
        for i, val in enumerate(test['grid']):
            grid_in |= ( (val-1) if val>0 else 0 ) << (2*i)
        
        dut.start.value = 1
        dut.k.value = test['k']
        dut.grid_in.value = grid_in
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 8 cycles)
        for _ in range(8):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        
        # Verify outputs
        if dut.valid_out.value != test['valid']:
            dut._log.error("VALID mismatch: got %d, expected %d for k=%d" % 
                          (dut.valid_out.value, test['valid'], test['k']))
        else:
            if test['valid']:
                # Verify full grid output
                out_grid = []
                for i in range(16):
                    cell = (dut.grid_out.value >> (2*i)) & 3
                    out_grid.append(cell + 1)
                if out_grid != test['expect_grid']:
                    dut._log.error("GRID mismatch. Output: %s Expected: %s" % 
                                  (str(out_grid), str(test['expect_grid'])))
                else:
                    passed += 1
            else:
                passed += 1
        
        await ClockCycles(dut.clk, 3)
    
    dut._log.info("Test Results: %d/%d passed" % (passed, len(test_data)))