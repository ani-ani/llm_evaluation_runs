import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_drawing_canvas(dut):
    """Test the drawing canvas with PAINT, SAVE, LOAD commands."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.cmd_type.value = 0
    dut.color.value = 0
    dut.x1.value = 0
    dut.y1.value = 0
    dut.x2.value = 0
    dut.y2.value = 0
    dut.load_idx.value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # --- Helper Function to run a command ---
    # In this design, we assume inputs are registered when start is high,
    # and the FSM processes it. Since M=8 is small, we can feed them sequentially.
    
    # To simplify interaction with the sequential FSM, we will drive inputs
    # and wait for the module to signal 'done' or enough time has passed.
    # However, for a simple benchmark, let's assume the testbench drives commands
    # and the DUT processes them. Since the prompt asks for a sequential module
    # that handles the log, we will drive the commands one by one.
    
    # Wait for reset to propagate
    await RisingEdge(dut.clk)
    
    # Helper to execute command
    async def execute_command(cmd, c, x_1, y_1, x_2, y_2, l_idx):
        dut.cmd_type.value = cmd
        dut.color.value = c
        dut.x1.value = x_1
        dut.y1.value = y_1
        dut.x2.value = x_2
        dut.y2.value = y_2
        dut.load_idx.value = l_idx
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for processing. For a 4x4 grid, it should be fast.
        # We wait a fixed number of cycles or until done is high.
        # Let's assume 20 cycles is enough for the loop unrolling.
        for _ in range(30):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

    # --- Run Test Sequence (from Sample Input 2 adapted to 4x4) ---
    # Original: 3 3 4
    # PAINT 3 0 0 1 1 -> Sets (0,0)=3 (even), (1,1)=3 (even)
    # SAVE
    # PAINT 2 1 1 2 2 -> Sets (1,1)=2 (even), (2,2)=2 (even)
    # LOAD 1 -> Reverts to state after first paint
    
    # Command 1: PAINT 3 0 0 1 1
    # cmd_type 0=PAINT
    await execute_command(0, 3, 0, 0, 1, 1, 0)
    
    # Command 2: SAVE
    # cmd_type 1=SAVE
    await execute_command(1, 0, 0, 0, 0, 0, 0)
    
    # Command 3: PAINT 2 1 1 2 2
    # cmd_type 0=PAINT
    await execute_command(0, 2, 1, 1, 2, 2, 0)
    
    # Command 4: LOAD 1
    # cmd_type 2=LOAD, load_idx=1
    await execute_command(2, 0, 0, 0, 0, 0, 1)
    
    # --- Verification ---
    # Expected Final State (from Sample Output 2 adapted to 4x4):
    # Row 0: 3 1 1 1
    # Row 1: 1 3 1 1
    # Row 2: 1 1 1 1
    # Row 3: 1 1 1 1
    
    # Note: The DUT output interface exposes pixel_data and pixel_addr during writes.
    # To verify the final grid, we ideally need to read back from internal memory.
    # Since the module spec only exposes write ports (for simulation of the process),
    # we will check the signals during the operations or assume a debug interface.
    # However, strictly adhering to the provided IO, we can't read the grid state.
    # The prompt implies the module generates pixel writes. We can verify the write sequence.
    # But for the "final result", we need the internal state.
    # 
    # CORRECTION: The testbench needs to verify the result. 
    # The module spec provided in the prompt is "drawing_canvas" which exposes pixel_wr.
    # To verify the final state, we must probe the internal memory or assume 
    # the DUT has an internal array `grid` that we can access in Python.
    # In cocotb, we can access internal signals: `dut.internal_grid_memory`
    # 
    # Let's assume the Verilog implements `reg [3:0] grid [0:3][0:3];`
    
    # Verify after LOAD 1
    # We check the internal grid state.
    
    dut._log.info("Checking final grid state...")
    
    grid = dut.grid
    
    # Expected: 
    # (0,0) = 3 (x+y=0 even)
    # (0,1) = 1 (x+y=1 odd, not painted)
    # (1,0) = 1 (x+y=1 odd, not painted)
    # (1,1) = 3 (x+y=2 even)
    
    # Check (0,0)
    assert grid[0][0].value == 3, f"Grid(0,0) expected 3, got {grid[0][0].value}"
    # Check (1,1)
    assert grid[1][1].value == 3, f"Grid(1,1) expected 3, got {grid[1][1].value}"
    
    # Check that (1,1) was NOT updated to 2 (since we loaded old state)
    # Actually, wait. The second PAINT was (1,1) to 2. (1+1=2 even). It would update.
    # Then LOAD 1 restores. So (1,1) must be 3.
    # Correct.
    
    # Let's also check a cell that should be 1.
    assert grid[0][1].value == 1, f"Grid(0,1) expected 1, got {grid[0][1].value}"
    
    dut._log.info("All assertions passed!")

