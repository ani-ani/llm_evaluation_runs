import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

@cocotb.test()
async def test_rook_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test case 1: 4x4 board with 4 rooks initial placement
    test_moves = [
        # (old_r, old_c, new_r, new_c, power)
        (0,0, 1,1, 1), # Place
        (0,0, 1,2, 1),
        (0,0, 3,3, 2),
        (0,0, 2,2, 3), 
        
        # Move moves
        (1,2, 1,3, 1),
        (2,2, 2,1, 3)
    ]
    expected = [16, 16, 16, 16, 14, 15] # Cycle counts after moves

    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for i, (r1,c1, r2,c2, pwr) in enumerate(test_moves):
        dut.old_r.value = r1
        dut.old_c.value = c1
        dut.incoming_r.value = r2
        dut.incoming_c.value = c2
        dut.incoming_power.value = pwr
        dut.start_move.value = 1
        await RisingEdge(dut.clk)
        dut.start_move.value = 0

        # Wait 17 cycles (1 for setup + 16 computation)
        for _ in range(17):
            await RisingEdge(dut.clk)
        if dut.done.value == 1 and dut.attacked_count.value == expected[i]:
            passed += 1
        else:
            dut._log.error(f"Move {i} failed: got {dut.attacked_count.value} expected {expected[i]} at step {i}")
    dut._log.info(f"{passed}/{len(test_moves)} tests passed")
")