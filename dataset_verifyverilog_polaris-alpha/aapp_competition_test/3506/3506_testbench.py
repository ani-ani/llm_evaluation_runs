import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_cheer(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        # Test 1: Sportify dominates minutes 0-2 (2 streak + 1 new
        # Opponent active in minutes 2-3 (0 goals)
        {
            'n': 1, 't': 3, 'm': 1,
            'intervals': [(2,4)],  # cheers in minutes 2-3
            'expected': (2, 0)  # Streaks: 0-1 (2-goal), 2-3 (opponent
                                 # but tie due to Sportify's minute2)
        },
        # Test 2: Tie all minutes (0 goals)
        {
            'n': 1, 't': 3,
            'm': 1,
            'intervals': [(0,4)],  # cheer minutes 0-3
            'expected': (0, 0)  # All ties when Sportify cheers 0-2
        },
        # Test 3: Opponent scores with back-to-back dominance
        {
            'n': 0, 't': 0,  # No Sportify cheerleaders
            'm': 2,
            'intervals': [(0,2), (1,3)],  # minutes0-1:2 cheers, minute2:1 cheer
            'expected': (0, 1)  # Opponent streak minutes1-2 (dominance)
        }
    ]
    passed = 0
    for test in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        
        # Apply inputs
        dut.n.value = test['n']
        dut.t.value = test['t']
        dut.m.value = test['m']
        for i in range(3):  # Init all interval inputs
            setattr(dut, f"interval_{i}_a", 0)
            setattr(dut, f"interval_{i}_b", 0)
        for idx, (a, b) in enumerate(test['intervals']):
            if idx < 3:
                getattr(dut, f"interval_{idx}_a").value = a
                getattr(dut, f"interval_{idx}_b").value = b
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        sportify = dut.sportify_goals.value
        spoilify = dut.spoilify_goals.value
        if sportify == test['expected'][0] and spoilify == test['expected'][1]:
            passed += 1
        else:
            dut._log.error(f"Failed: Got {sportify}-{spoilify}, Expected {test['expected']}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")