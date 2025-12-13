import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_turtle(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # Test 1: 2x2 grid - complete coverage
        {"target": 0b0000, 
         "cmds": [("up", 1), ("right", 1), ("down", 1), ("left", 1)],  # Square path
         "exp_min": 0, "exp_max": 3, "valid": 1}
    ]
    # Direction encoding mapping
    dir_map = {"up": 0, "down": 1, "left": 2, "right": 3}
    passed = 0
    for idx, tc in enumerate(test_cases):
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        # Load target grid (16 bits packed row-major bits [3][0] to [0][3])
        dut.target_grid.value = tc["target"]
        # Load commands
        cmds = tc["cmds"]
        dut.num_cmds.value = len(cmds)
        for i in range(8):
            cmd_val = 0
            if i < len(cmds):
                dir, dist = cmds[i]
                cmd_val = (min(dist,15) << 4) | dir_map[dir]
            getattr(dut, f"cmd_{i}").value = cmd_val
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        # Check results
        valid = dut.valid_result.value
        min_t = dut.min_time.value
        max_t = dut.max_time.value
        if valid == tc["valid"] and min_t == tc["exp_min"] and max_t == tc["exp_max"]:
            passed += 1
        else:
            dut._log.error(f"Test {idx} failed: got min={min_t} max={max_t} valid={valid} (expected min={tc['exp_min']} max={tc['exp_max']} valid={tc['valid']})")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
