import cocotb
from cocotb.triggers import Timer
import math

@cocotb.test()
async def test_max_fill(dut):
    test_cases = [
        (0x24F0, 1, 6),   # [[0,0,1,0],[0,1,0,0],[1,1,1,1],[0,0,0,0]] cap=1
        (0x30F7, 2, 5),   # [[0,0,1,1],[0,0,0,0],[1,1,1,1],[0,1,1,1]] cap=2
        (0x0000, 5, 0),   # All zeros padded to 4x4
        (0xFF00, 2, 4),   # [[1,1,1,1],[1,1,1,1],[0,0,0,0],[0,0,0,0]] cap=2
        (0xFF00, 9, 2)    # Same grid, cap=9
    ]
    
    passed = 0
    for grid_val, cap_val, expected in test_cases:
        dut.grid.value = grid_val
        dut.capacity.value = cap_val
        await Timer(1, units='ns')  # Combinational delay
        if int(dut.total_trips.value) == expected:
            passed += 1
            dut._log.info(f"PASS: grid=0x{grid_val:04X}, cap={cap_val} -> {expected}")
        else:
            dut._log.error(f"FAIL: grid=0x{grid_val:04X}, cap={cap_val} got {dut.total_trips.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")