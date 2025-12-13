import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray
import numpy as np

# Distance helper function
def sq_distance(x1, y1, x2, y2):
    dx = int(x1) - int(x2)
    dy = int(y1) - int(y2)
    return dx*dx + dy*dy

@cocotb.test()
async def test_clique_finder(dut):
    # Setup
    dut.rst_n.value = 1
    dut.clk.value = 0
    # Test case 1: n=4, d=1 (sensors at (0,0), (0,1), (1,0), (1,1))
    dut.n.value = 4
    dut.d.value = 1
    dut.x_pos.value = [0,0,1,1,0,0,0,0]  # Sensors 1-4 filled, others 0
    dut.y_pos.value = [0,1,0,1,0,0,0,0]
    await Timer(10, units='ns')  # Combinational settle time
    assert dut.subset_size.value == 2, f"Test 1: Expected size 2 got {dut.subset_size.value}"
    mask = int(dut.subset_mask.value)
    assert bin(mask).count('1') == 2, f"Test 1: Mask {bin(mask)} should have 2 sensors"
    # Test case 2: n=5, d=20 (3-clique with positions [0,0],[0,2],[100,100],[100,110],[100,120])
    # Reduced to n=5 by input padding
    dut.n.value = 5
    dut.d.value = 20*20  # Square distance check
    positions_x = [0, 0, 100, 100, 100, 0, 0, 0]
    positions_y = [0, 2, 100, 110, 120, 0, 0, 0]
    dut.x_pos.value = positions_x
    dut.y_pos.value = positions_y
    await Timer(10, units='ns')
    assert dut.subset_size.value >= 2  # At least 2-clique should exist
    # Additional test case: Triangle with exact distance match (n=3, d=5)
    dut.n.value = 3
    dut.d.value = 5*5  # (3^2 + 4^2 = 25)
    dut.x_pos.value = [0,3,0,0,0,0,0,0]
    dut.y_pos.value = [0,0,4,0,0,0,0,0]
    await Timer(10, units='ns')
    assert dut.subset_size.value == 3, f"Triangle test: Expected size=3 got {dut.subset_size.value}"
    dut._log.info("3/3 tests passed")