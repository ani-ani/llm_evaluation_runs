import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_coin_payer(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (P, [N1, N5, N10, N25], expected_coins, expected_impossible)
    test_cases = [
        (13, [3, 2, 1, 1], 5, 0),  # Original sample
        (13, [2, 2, 1, 1], 0, 1),  # Impossible case
        (100, [15, 15, 15, 4], 4, 0),  # 4x25c
        (100, [0, 0, 0, 5], 4, 0),  # More 25c than needed
        (7, [2, 1, 3, 0], 3, 0),   # 1x5c + 2x1c = 3 coins
        (255, [15,15,15,15], 15+3+1+0, 0),  # Max P: 15x25c=375→overflow, max 10x25c=250 +1x5c=255
    ]
    
    passed = 0
    dut._log.info("Starting tests")
    
    for p, coins, exp_coins, exp_imp in test_cases:
        # Reset
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        
        # Setup inputs
        dut.P.value = p
        dut.N1.value = coins[0]
        dut.N5.value = coins[1]
        dut.N10.value = coins[2]
        dut.N25.value = coins[3]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 4 cycles for result
        await ClockCycles(dut.clk, 4)
        
        # Check outputs
        if dut.done.value != 1:
            dut._log.error("Done not asserted at expected time")
        
        if dut.impossible.value == exp_imp:
            if exp_imp == 0 and dut.coins_used.value == exp_coins:
                passed += 1
            elif exp_imp == 1:
                passed += 1
            else:
                dut._log.error(f"Test failed: P={p}, coins={coins}
                    Expected coins={exp_coins}, impossible={exp_imp}
                    Got coins={dut.coins_used.value}, impossible={dut.impossible.value}")
        else:
            dut._log.error(f"Test failed: P={p}, coins={coins}
                Expected impossible={exp_imp}, got {dut.impossible.value}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")