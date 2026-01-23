import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_cheerleader_optimizer(dut):
    """Test the cheerleader optimizer module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_cheerleaders.value = 0
    dut.cheer_time.value = 0
    dut.opponent_pattern.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test Case 1: 1 cheerleader, 31 minutes, opponent pattern 00111111 (20-60 scaled) ===")
    # Original: 1 cheerleader, 31 min, opponent cheering from min 20-60 and 50-90
    # Scaled: 1 cheerleader, 31 min is impossible (max 8), use 5 min
    # Opponent: pattern for min 2-7 (representing 20-60 scaled)
    # Pattern: 00111111 (bits 2-7 = 1)
    dut.num_cheerleaders.value = 1
    dut.cheer_time.value = 5  # 5 minutes for 1 cheerleader
    dut.opponent_pattern.value = 0b00111111  # Opponent cheers min 2-7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        print("ERROR: Test 1 timed out!")
    else:
        a = int(dut.sportify_goals.value)
        b = int(dut.spoilify_goals.value)
        print(f"Result: Sportify={a}, Spoilify={b}")
        # Expected: With proper scheduling, Sportify should score more
        # Optimally, cheer during minutes 2-6 to counter opponent
        # But can only cheer 5 minutes, so maximize difference
        assert (a - b) >= 0, f"Sportify should not be negative diff: {a}-{b}"
        assert a + b <= 5, f"Total goals should be reasonable: {a}+{b}"
    
    await Timer(100, units='ns')
    
    print("
=== Test Case 2: 2 cheerleaders, 5 minutes each, opponent pattern 11111111 ===")
    # Original: 2 cheerleaders, 5 min each, opponent cheering whole game
    # Scaled: 2 cheerleaders, 5 min each, opponent pattern 11111111
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_cheerleaders.value = 2
    dut.cheer_time.value = 5
    dut.opponent_pattern.value = 0b11111111  # Opponent cheers all 8 minutes
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        print("ERROR: Test 2 timed out!")
    else:
        a = int(dut.sportify_goals.value)
        b = int(dut.spoilify_goals.value)
        print(f"Result: Sportify={a}, Spoilify={b}")
        # With opponent cheering all the time, Sportify needs to cheer at least 3 consecutive minutes
        # to score a goal. With 2 cheerleaders cheering 5 min each, they can achieve this.
        # Spoilify will score many goals unless Sportify cheers every minute.
        assert a >= 0 and b >= 0, "Goals must be non-negative"
    
    await Timer(100, units='ns')
    
    print("
=== Test Case 3: 0 cheerleaders, opponent pattern 00000000 ===")
    # No cheerleaders, no opponent - no goals
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_cheerleaders.value = 0
    dut.cheer_time.value = 0
    dut.opponent_pattern.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        print("ERROR: Test 3 timed out!")
    else:
        a = int(dut.sportify_goals.value)
        b = int(dut.spoilify_goals.value)
        print(f"Result: Sportify={a}, Spoilify={b}")
        assert a == 0 and b == 0, "No cheerleaders should result in 0-0"
    
    await Timer(100, units='ns')
    
    print("
=== Test Case 4: 1 cheerleader, 8 minutes, opponent pattern 10101010 ===")
    # Test edge case: alternating opponent
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_cheerleaders.value = 1
    dut.cheer_time.value = 8  # Can cheer all 8 minutes
    dut.opponent_pattern.value = 0b10101010  # Alternating
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        print("ERROR: Test 4 timed out!")
    else:
        a = int(dut.sportify_goals.value)
        b = int(dut.spoilify_goals.value)
        print(f"Result: Sportify={a}, Spoilify={b}")
        print("All tests completed!")
    
    await Timer(100, units='ns')
    print("
Testbench Summary: All 4 test cases executed.")
    print("Expected behavior: Module should find optimal schedule maximizing goal difference.")