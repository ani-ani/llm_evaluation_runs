import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_robot_path_solver(dut):
    """Test the robot path solver with scaled inputs"""
    # Create a clock with a 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.target_a.value = 0
    dut.target_b.value = 0
    dut.cmd_addr.value = 0
    dut.cmd_char.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper function to load commands
    async def load_commands(cmd_string):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for LOAD_CMD state (assuming it's the next state after IDLE on start)
        # We need to feed commands one by one
        # Based on prompt: In LOAD_CMD state, read 8 commands
        # We need to drive inputs for 8 cycles
        for i, char in enumerate(cmd_string):
            dut.cmd_addr.value = i
            dut.cmd_char.value = ord(char)
            await RisingEdge(dut.clk)
        # After 8 cycles, transition to PROCESS usually requires a signal or state logic
        # Since the prompt implies sequential loading, we might need to wait or drive specific signals.
        # Assuming the design automatically transitions to PROCESS after 8 loads or requires a handshake.
        # To be safe, let's assume the design handles the loading internally once start is high.
        # However, a typical implementation would require valid signals.
        # Let's assume the DUT expects the commands to be fed in the LOAD_CMD state.
        # If the DUT stays in LOAD_CMD for 8 cycles, we feed them.
        # But since we just wait for RisingEdge in the loop, we are feeding 8 cycles.
    
    # Test Case 1: Target (2, 2), Command "RU" -> Yes (scaled to 8-bit is fine)
    # Command: R (1,0), U (0,1) -> (1,1). Repeated: (1,1), (2,2)
    dut.target_a.value = 2
    dut.target_b.value = 2
    # We need to inject 'R' and 'U' into the command array.
    # The prompt says input is cmd_addr and cmd_char. We need to drive these during LOAD state.
    # Let's start the sequence manually
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load 8 commands (only first 2 matter for this test)
    # 'R' = 0x52, 'U' = 0x55
    dut.cmd_addr.value = 0
    dut.cmd_char.value = ord('R')
    await RisingEdge(dut.clk)
    dut.cmd_addr.value = 1
    dut.cmd_char.value = ord('U')
    await RisingEdge(dut.clk)
    for i in range(2, 8):
        dut.cmd_addr.value = i
        dut.cmd_char.value = ord('U') # Fill with dummy
        await RisingEdge(dut.clk)

    # Wait for processing
    # We need to monitor 'done' and 'found'
    # Let's wait for a reasonable amount of time for the state machine to process 16 steps
    # 16 steps + overhead. Let's wait 100 cycles
    found = False
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            if dut.found.value == 1:
                found = True
            break
    
    if not found:
        raise TestFailure(f"Test Case 1 Failed: Expected found=1 for target (2,2) with commands 'RU', but got found={dut.found.value}")
    
    print("Test Case 1 Passed: (2,2) with 'RU' -> Yes")

    # Test Case 2: Target (1, 2), Command "RU" -> No
    # Path: (0,0) -> (1,0) -> (1,1) -> (2,1) -> (2,2)
    # (1,2) is not in the path.
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.target_a.value = 1
    dut.target_b.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.cmd_addr.value = 0
    dut.cmd_char.value = ord('R')
    await RisingEdge(dut.clk)
    dut.cmd_addr.value = 1
    dut.cmd_char.value = ord('U')
    await RisingEdge(dut.clk)
    for i in range(2, 8):
        dut.cmd_addr.value = i
        dut.cmd_char.value = ord('U')
        await RisingEdge(dut.clk)

    found = False
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            if dut.found.value == 1:
                found = True
            break
    
    if found:
        raise TestFailure(f"Test Case 2 Failed: Expected found=0 for target (1,2) with commands 'RU', but got found={dut.found.value}")
    
    print("Test Case 2 Passed: (1,2) with 'RU' -> No")

    # Test Case 3: Target (0, 0), Command "D" -> Yes
    # Path: (0,0) -> (0,-1) -> (0,-2). Start is (0,0).
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.target_a.value = 0
    dut.target_b.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.cmd_addr.value = 0
    dut.cmd_char.value = ord('D')
    await RisingEdge(dut.clk)
    for i in range(1, 8):
        dut.cmd_addr.value = i
        dut.cmd_char.value = ord('U') # Dummy
        await RisingEdge(dut.clk)

    found = False
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            if dut.found.value == 1:
                found = True
            break
    
    if not found:
        raise TestFailure(f"Test Case 3 Failed: Expected found=1 for target (0,0) with commands 'D', but got found={dut.found.value}")
    
    print("Test Case 3 Passed: (0,0) with 'D' -> Yes")

    # Test Case 4: Target (4, 4), Command "UURR" (Repeated)
    # Command: U(0,1), U(0,1), R(1,0), R(1,0). Sum = (2,2).
    # Path: (0,0) -> (0,1) -> (0,2) -> (1,2) -> (2,2) -> (2,3) -> (2,4) -> (3,4) -> (4,4)
    # This falls within 2 repetitions (8 steps total).
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.target_a.value = 4
    dut.target_b.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    dut.cmd_addr.value = 0
    dut.cmd_char.value = ord('U')
    await RisingEdge(dut.clk)
    dut.cmd_addr.value = 1
    dut.cmd_char.value = ord('U')
    await RisingEdge(dut.clk)
    dut.cmd_addr.value = 2
    dut.cmd_char.value = ord('R')
    await RisingEdge(dut.clk)
    dut.cmd_addr.value = 3
    dut.cmd_char.value = ord('R')
    await RisingEdge(dut.clk)
    for i in range(4, 8):
        dut.cmd_addr.value = i
        dut.cmd_char.value = ord('U')
        await RisingEdge(dut.clk)

    found = False
    for _ in range(150): # Might take longer
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            if dut.found.value == 1:
                found = True
            break
    
    if not found:
        raise TestFailure(f"Test Case 4 Failed: Expected found=1 for target (4,4) with commands 'UURR', but got found={dut.found.value}")
    
    print("Test Case 4 Passed: (4,4) with 'UURR' -> Yes")

    # Test Case 5: Target (-1, 1), Command "LRRLU"
    # Scaled: target (-1, 1)
    # Command: L(-1,0), R(1,0), R(1,0), L(-1,0), U(0,1). Sum = (0,1).
    # Path: (0,0) -> (-1,0) -> (0,0) -> (1,0) -> (0,0) -> (0,1). 
    # Wait, repeating "LRRLU" (length 5). Prompt limits to N=8, so this fits.
    # Repetitions: 
    # Step 1: (-1,0)
    # Step 2: (0,0)
    # Step 3: (1,0)
    # Step 4: (0,0)
    # Step 5: (0,1)
    # Step 6: (-1,1) <-- Target hit in 2nd repetition (6th step)
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.target_a.value = -1
    dut.target_b.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    commands = ['L', 'R', 'R', 'L', 'U']
    for i, char in enumerate(commands):
        dut.cmd_addr.value = i
        dut.cmd_char.value = ord(char)
        await RisingEdge(dut.clk)
    for i in range(len(commands), 8):
        dut.cmd_addr.value = i
        dut.cmd_char.value = ord('U')
        await RisingEdge(dut.clk)

    found = False
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            if dut.found.value == 1:
                found = True
            break
    
    if not found:
        raise TestFailure(f"Test Case 5 Failed: Expected found=1 for target (-1,1) with commands 'LRRLU', but got found={dut.found.value}")
    
    print("Test Case 5 Passed: (-1,1) with 'LRRLU' -> Yes")
