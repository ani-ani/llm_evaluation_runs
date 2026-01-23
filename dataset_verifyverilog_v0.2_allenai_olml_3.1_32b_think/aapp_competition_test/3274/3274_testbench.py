import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper to pack instruction string to bits (0=straight, 1=turn)
def pack_instructions(instr_str):
    val = 0
    for i, char in enumerate(instr_str):
        if char != '0': # '+' or '-'
            val |= (1 << i)
    return val

@cocotb.test()
async def test_torpedo_dodger(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Sample Input 1 (Scaled Down for N=16)
    # Original: 5s, 6 ships. Scaled: N=16, scale factor 2
    # Ships: (-3,-2,3) -> (-6,-4,6), (-2,-2,4)->(-4,-4,8), (2,3,3)->(4,6,6)
    # (-1,1,2)->(-2,2,4), (0,1,4)->(0,2,8), (2,5,1)->(4,10,2)
    # Map to 0-indexed y for array access (y-1 if y>0)
    # We will configure 8 ships. Max coordinate is 10, fits in 6 bits.
    
    ships = [
        (6, 4, 6),   # x1=6, x2=4 (note: x1 <= x2), y=6 -> inverted logic check needed
        (4, 4, 8),
        (4, 6, 6),
        (2, 2, 4),
        (0, 2, 8),
        (4, 10, 2)
    ]
    
    # Correct x1 <= x2 requirement
    ships = [
        (4, 6, 6),   # was (-3,-2) -> 6, 4 is wrong order, -3 -> 6, -2 -> 8? Wait.
        # Let's use strictly positive coords for simplicity or handle signs?
        # The prompt allows [-N, N]. Let's use 0-15 range to avoid complex sign logic in testbench.
        # Let's define a simple valid case.
        # N=16. Ship at y=2 covering x=2 to 4.
        # Ship at y=4 covering x=1 to 5.
        # Ship at y=6 covering x=6 to 8.
        # Expect path to wiggle around.
    ]
    
    # Revised Test Case 1: Avoid 2 ships
    # N=16. Ships at y=2 [2,4], y=4 [1,5]. Start (0,0).
    # Expected output: likely '+++' or '++0' to go right, then '---' to go left if needed.
    # Let's manually verify: Start at x=0.
    # t=1: x=1 (turn right). t=2: x=2. SHIP at y=2 [2,4]. x=2 is hit. 
    # So must be at x=1 or x=3 at t=2. x=1 comes from x=0 (right) -> x=1? No.
    # x=0 -> turn right -> x=1. Wait.
    # x=0 -> '+' -> x=1. x=1 -> '+' -> x=2. (Hit)
    # x=0 -> '0' -> x=0. x=0 -> '+' -> x=1. (Safe at t=2)
    # So prefix '0+' is good. Then need to navigate y=4 ship [1,5].
    # At t=2 (y=2), x=1. 
    # t=3: x can be 0, 1, 2. 
    # t=4: x can be -1, 0, 1, 2, 3.
    # Ship at y=4 covers [1,5]. Must be at x=0 or x=-1 or x=6+ (impossible).
    # To get to x=0 at t=4 from x=1 at t=2:
    # t=2: x=1. t=3: x=0 ('-'). t=4: x=0 ('0'). Safe.
    # So path: '0+00'.
    
    num_ships = 2
    dut.num_ships.value = num_ships
    
    # Initialize arrays to 0
    for i in range(8):
        dut.ship_x1[i].value = 0
        dut.ship_x2[i].value = 0
        dut.ship_y[i].value = 0

    # Ship 1: y=2 (index 1), x=[2,4] -> 0-indexed y=1
    # Module expects y input directly? Prompt says "ship_y [0:7]".
    # Let's assume y values are 1-based coordinates.
    dut.ship_x1[0].value = 2
    dut.ship_x2[0].value = 4
    dut.ship_y[0].value = 2
    
    # Ship 2: y=4 (index 3), x=[1,5]
    dut.ship_x1[1].value = 1
    dut.ship_x2[1].value = 5
    dut.ship_y[1].value = 4
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1, "Timeout waiting for done"
    assert dut.possible.value == 1, "Should be possible"
    
    # Check path
    # Expected: '0+00' for first 4 bits. 
    # 0 (index 0) -> 0
    # 1 (index 1) -> 1
    # 2 (index 2) -> 0
    # 3 (index 3) -> 0
    # Bits: 0010 in binary (LSB first if index 0 is bit 0)? 
    # Verilog output is [15:0] path_data. Usually bit 0 is step 0.
    # '0' = 0, '+' = 1, '-' = 1 (we just need !=0).
    # Expected bits: 0, 1, 0, 0. (Value = 0b0010 = 2)
    # But wait, '0' is straight, '-' and '+' are turns.
    # Let's check the logic. '0+00' -> bits: 0, 1, 0, 0. Value = 2.
    
    print(f"Path Data: {dut.path_data.value}")
    path_val = int(dut.path_data.value)
    # Check bit 1 is set (step 1 turn), others unset for first 4 steps
    assert (path_val & 0x2) != 0, "Step 1 should be turn"
    assert (path_val & 0x1) == 0, "Step 0 should be straight"
    assert (path_val & 0x4) == 0, "Step 2 should be straight"
    
    # Test Case 2: Impossible Case
    # Single ship covering entire width at y=1. [0, 10] at y=1.
    # N=16. 
    # Start (0,0). At t=1, reachable x: -1, 0, 1. 
    # Ship covers [0, 10]. Must be at -1 or >10.
    # Can reach -1 (turn left). Safe.
    # So simple overlapping might not be impossible unless it's wider.
    # Let's try ship at y=1 [0, 0] and ship at y=2 [-1, 1].
    # At t=1, x must be -1, 0, 1. If ship at 0 blocks 0.
    # At t=2, reachable from -1: -2, -1, 0. From 0: -1, 0, 1. From 1: 0, 1, 2.
    # Union is -2 to 2. Ship at [-1, 1] blocks middle. 
    # Reachable at t=2: -2, 2. 
    # At t=3, from -2: -3, -2, -1. From 2: 1, 2, 3. 
    # If there is a ship at t=3 covering [-3, 3], it's impossible.
    
    dut.start.value = 1
    dut.num_ships.value = 3
    
    # Ship 1: y=1, x=[0,0] (blocks straight)
    dut.ship_x1[0].value = 0
    dut.ship_x2[0].value = 0
    dut.ship_y[0].value = 1
    
    # Ship 2: y=2, x=[-1,1] (blocks pass)
    # Note: Input range is [-n, n]. In verilog, we need to handle signed.
    # But simplified test uses positive.
    # Let's make it impossible with positive values.
    # Ship 1: y=1, x=[0,0]
    # Ship 2: y=2, x=[2,2] (blocks right path)
    # Ship 3: y=3, x=[1,3] (blocks return)
    # Let's stick to the python example 3: "3 2
1 2 1
-2 1 2
"
    # Ships: (1,2,1) and (-2,1,2).
    # y=1: [1,2]. y=2: [-2,1].
    # Start (0,0). 
    # t=1: x=-1,0,1. Ship at [1,2] blocks x=1. Valid: -1, 0.
    # t=2: From -1: -2,-1,0. From 0: -1,0,1. Union: -2 to 1.
    # Ship at [-2,1] blocks all. Impossible.
    
    # Configure for this case. X range is -2 to 2. 
    # We need to handle signed inputs for -2.
    # 6-bit signed input.
    
    dut.ship_x1[0].value = 1 & 0x3F # 1
    dut.ship_x2[0].value = 2 & 0x3F # 2
    dut.ship_y[0].value = 1
    
    # -2 in 6-bit 2's complement: 0x3E (binary 111110)
    # But Verilog input port is [5:0]. 
    # If we assign 10 (Python int) to 6-bit signal, it takes lower 6 bits.
    # -2 as Python int is ...1111111110 (infinite 1s). 0xFFFFFFFE.
    # Lower 6 bits: 111110 = 62.
    dut.ship_x1[1].value = (-2) & 0x3F
    dut.ship_x2[1].value = (1) & 0x3F
    dut.ship_y[1].value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1
    assert dut.possible.value == 0, "Should be impossible"
    print("Test Passed: Impossible case detected")
    
    print(f"Total tests: 2 Passed")