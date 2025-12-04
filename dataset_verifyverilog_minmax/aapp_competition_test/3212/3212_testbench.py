import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_snake_path(dut):
    # Scale test cases to 256x256 grid (original / 3.90625)
    def scale(v):
        return int(v * 255.0 / 1000.0)
    
    test_cases = [
        # TC1: Sample Input 1
        {'snakes': [(scale(500), scale(500), scale(499)), (scale(0), scale(0), scale(999)), (scale(1000), scale(1000), scale(200))],
         'expected': (255, 204), 'bitten': False},
        # TC2: Sample Input 2
        {'snakes': [(scale(250), scale(250), scale(300)), (scale(750), scale(250), scale(300)), 
                   (scale(250), scale(750), scale(300)), (scale(750), scale(750), scale(300))],
         'expected': (0, 0), 'bitten': True},
        # TC3: Single snake at center
        {'snakes': [(scale(500), scale(500), scale(500))], 'expected': (255, 255), 'bitten': False}
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    for idx, tc in enumerate(test_cases):
        dut._log.info(f"Testing case {idx+1}")
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.snake_valid.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load snakes
        dut.snake_count.value = len(tc['snakes'])
        for i, snake in enumerate(tc['snakes']):
            x, y, d = snake
            dut.snake_data.value = (d << 16) | (y << 8) | x
            dut.snake_valid.value = 1
            await RisingEdge(dut.clk)
        dut.snake_valid.value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (1024 cycles max)
        for _ in range(1030):
            await RisingEdge(dut.clk)
            if dut.valid_out.value == 1:
                break
        else:
            assert False, "Timeout waiting for valid_out"
        
        # Check results
        entry_y = dut.entry_exit.value & 0xFF
        exit_y = (dut.entry_exit.value >> 8) & 0xFF
        if tc['bitten']:
            assert dut.bitten.value == 1, f"TC{idx+1} should show bitten but passed"
        else:
            assert dut.bitten.value == 0, f"TC{idx+1} should have path but failed"
            assert entry_y == tc['expected'][0], f"TC{idx+1} entry_y {entry_y} != expected {tc['expected'][0]}"
            assert exit_y == tc['expected'][1], f"TC{idx+1} exit_y {exit_y} != expected {tc['expected'][1]}"
        passed += 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")