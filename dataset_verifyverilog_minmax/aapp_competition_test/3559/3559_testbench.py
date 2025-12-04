import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_zerg_sim(dut):
    # Test cases adapted for 2x2 grid, 0-3 turns
    test_cases = [
        {'input': 2, 'p1_attack': 0, 'p1_armor': 0, 'p2_attack': 0, 'p2_armor': 0, 'init_grid': 0x90, 'turns': 0, 'expected': 0x90}, # "1.
..
" (0x90 = 10010000)
        {'input': 2, 'p1_attack': 0, 'p1_armor': 0, 'p2_attack': 0, 'p2_armor': 0, 'init_grid': 0x94, 'turns': 1, 'expected': 0x00}  # "1.
.2
" → both attack and die
    ]
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    passed = 0
    for test in test_cases:
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        dut.p1_attack_upgrade.value = test['p1_attack']
        dut.p1_armor_upgrade.value = test['p1_armor']
        dut.p2_attack_upgrade.value = test['p2_attack']
        dut.p2_armor_upgrade.value = test['p2_armor']
        dut.init_grid.value = test['init_grid']
        dut.turns.value = test['turns']
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max cycles: (turns+1)*5 + 3)
        max_wait = (test['turns'] + 1)*5 + 3
        for _ in range(max_wait):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.final_grid.value == test['expected']:
            passed += 1
        else:
            dut._log.error("Test failed: Expected %x got %x" % (test['expected'], dut.final_grid.value))
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))