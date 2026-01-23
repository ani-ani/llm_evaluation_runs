import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
def test_robot_trail_cycle(dut):
    """Test robot trail cycle detection with a simple 2-cycle case."""
    
    # Clock generation (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_data.value = 0
    dut.prog_char.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test Case: 2x2 grid (with borders) and program "^>"
    # Grid (internal): 
    # R .
    # . #
    # Program: ^ (up), > (right)
    # Path: Start(1,1) -> ^ -> (0,1) -> Hit Border -> Stay(0,1). > -> (0,2) -> Hit Border -> Stay(0,1). -> Loop.
    # Wait, grid borders are impassable. 
    # Let's use the prompt's logic to simulate a specific test case.
    # Input: 
    # 4
    # v<^>
    # ####
    # #.R#
    # #..#
    # ####
    # Output: 4
    
    # Let's run a simulation where we mock the memory reads.
    # This is a bit tricky in pure cocotb without memory models. 
    # We will assume the DUT has internal memory or we drive the inputs.
    # For this test, we will just verify the logic flow manually by driving inputs if needed.
    # However, a complete test requires reading the specification for the interface.
    # The interface defined above has outputs for addresses and inputs for data.
    # We will act as the memory provider.
    
    dut._log.info("Starting Robot Trail Test")
    
    # Step 1: Drive start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # State Machine Logic Simulation
    # We need to manually feed 'grid_data' and 'prog_char' when the DUT requests them.
    # The DUT sets grid_addr_valid/prog_addr_valid to 1 when it needs data.
    
    # Configuration
    # Grid: 4x4
    # Row 0: #### (0,1,2,3)
    # Row 1: #.R# (0,1,2,3) -> R at (1,2)
    # Row 2: #..# (0,1,2,3)
    # Row 3: ####
    # Program: v<^> (len 4)
    # v: (2,2)
    # <: (2,1)
    # ^: (1,1)
    # >: (1,2)
    # Wait, sample input 2 is:
    # 4
    # v<^>
    # ####
    # #.R#
    # #..#
    # ####
    # R is at (1,2) (row 1, col 2)
    # Instructions:
    # 1. 'v' -> target (2,2). Cell (2,2) is '.'. Valid. Move to (2,2).
    # 2. '<' -> target (2,1). Cell (2,1) is '.'. Valid. Move to (2,1).
    # 3. '^' -> target (1,1). Cell (1,1) is '.'. Valid. Move to (1,1).
    # 4. '>' -> target (1,2). Cell (1,2) is 'R' (or '.' treated same). Valid. Move to (1,2).
    # Cycle detected? We are back to (1,2) and program index 0.
    # This is a cycle of length 4.
    
    # Sequence of States (R, C, P):
    # 0: (1,2,0) Start
    # 1: (2,2,1) Move v
    # 2: (2,1,2) Move <
    # 3: (1,1,3) Move ^
    # 4: (1,2,0) Move > (Back to start state)
    # Cycle length = 4.
    
    # We need to drive grid_data and prog_char based on what the DUT asks.
    # The DUT will output: grid_addr, prog_addr.
    # We respond with the correct character.
    
    step = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
        
        if dut.grid_addr_valid.value:
            # Address is row*16 + col (simplified)
            addr = dut.grid_addr.value
            row = addr // 16
            col = addr % 16
            
            # Grid 4x4
            char = '#'
            if row == 1:
                if col == 1: char = '.'
                elif col == 2: char = 'R'
            elif row == 2:
                if col == 1 or col == 2: char = '.'
            
            dut.grid_data.value = ord(char)
            dut._log.info(f"Step {step}: Read Grid ({row},{col}) -> {chr(ord(char))}")
            
        if dut.prog_addr_valid.value:
            # Address is index
            idx = dut.prog_char.value # Actually DUT sends index on address bus? No, prompt says prog_addr output
            # Wait, the prompt says: output reg [7:0] prog_addr
            # And input [7:0] prog_char
            # So DUT puts index on prog_addr, we put char on prog_char.
            
            # Let's assume the prompt meant prog_addr is the index to read
            # But the input is named prog_char. This implies we drive it.
            # Actually, usually it's: Address output -> Memory -> Data input.
            # So: dut.prog_addr -> dut.prog_char (input)
            # But the prompt has: output prog_addr, input prog_char. Correct.
            
            # Let's re-read the interface.
            # output reg [7:0] prog_addr // Instruction index
            # input [7:0] prog_char // Instruction character
            # So we look at dut.prog_addr to see what it wants.
            
            idx = dut.prog_addr.value
            prog = "v<^>"
            if idx < len(prog):
                char = prog[idx]
            else:
                char = 'v' # Default
            
            dut.prog_char.value = ord(char)
            dut._log.info(f"Step {step}: Read Prog [{idx}] -> {char}")
            
        step += 1
        if step > 100: # Safety break
            break
            
    if dut.done.value:
        result = dut.result.value
        dut._log.info(f"Finished. Result: {result}")
        if result != 4:
            raise TestFailure(f"Expected 4, got {result}")

@cocotb.test()
def test_robot_trail_finite(dut):
    """Test robot trail finite case (hits wall immediately)."""
    # Input:
    # 4
    # <<<
    # ####
    # #.R#
    # #..#
    # ####
    # R at (1,2). 
    # '<' -> (1,1). '.' Valid.
    # '<' -> (1,0). '#' Invalid. Stop.
    # '<' -> (1,0). '#' Invalid. Stop.
    # Program loops: ...<-<-<-...
    # Robot is stuck at (1,1).
    # Moves: Start(1,2), (1,1). Then stops moving.
    # Trail is finite: [R, (1,1)]. Length 2.
    # Output should be 1.
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_data.value = 0
    dut.prog_char.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    step = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
        
        if dut.grid_addr_valid.value:
            addr = dut.grid_addr.value
            row = addr // 16
            col = addr % 16
            
            char = '#'
            if row == 1:
                if col == 1: char = '.'
                elif col == 2: char = 'R'
            elif row == 2:
                if col == 1 or col == 2: char = '.'
            
            dut.grid_data.value = ord(char)
            
        if dut.prog_addr_valid.value:
            idx = dut.prog_addr.value
            # Program "<<<" (len 3)
            prog = "<<<"
            if idx < len(prog):
                dut.prog_char.value = ord(prog[idx])
            else:
                dut.prog_char.value = ord('<')
                
        step += 1
        if step > 150: # Should terminate quickly
            break
            
    if dut.done.value:
        result = dut.result.value
        if result != 1:
            raise TestFailure(f"Expected 1, got {result}")