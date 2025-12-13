import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_invites(dut):
    # Scaled test cases (original samples adapted)
    test_cases = [
        (2, [[9, 16], [10, 16]], 1, [16]),  # Friend=9 not needed (same as sample 1)
        (4, [[9, 17], [9, 18], [2, 19], [3, 19]], 2, [19, 9])  # Friend=9 included (sample 2)
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for (num, teams, exp_k, exp_ids) in test_cases:
        # Load input data
        dut.num_teams.value = num
        for i in range(8):
            if i < num:
                dut.teams_i[i].value = (teams[i][0] << 5) | teams[i][1]
            else:
                dut.teams_i[i].value = 0
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 8 cycles)
        for _ in range(10):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        # Check results
        actual_ids = [dut.invitees[i].value for i in range(exp_k)]
        
        if dut.k.value == exp_k and set(actual_ids) == set(exp_ids):
            passed += 1
        else:
            dut._log.error(
                f"Test failed: num_teams={num}
                 Expected k={exp_k} IDs={exp_ids}
                 Got k={dut.k.value} IDs={actual_ids}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")