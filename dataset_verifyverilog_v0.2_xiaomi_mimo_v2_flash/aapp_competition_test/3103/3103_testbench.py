import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# ASCII values for characters
CHAR_TILDE = ord('~')
CHAR_HASH = ord('#')
CHAR_AT = ord('@')
CHAR_GT = ord('>')
CHAR_LT = ord('<')

async def load_grid(dut, grid_map):
    """Helper to load grid data row by row."""
    # The DUT drives load_row. We provide grid_char.
    # Wait for load_row to change from X or 0 to a valid index.
    # The DUT will request rows sequentially.
    
    rows_requested = set()
    max_rows = 16
    
    # We need to detect when the DUT requests a row and feed it.
    # Since we are driving inputs based on DUT outputs, we need to monitor load_row.
    
    # Simple approach: loop until all rows handled or done is high
    for _ in range(500): # Safety limit
        if dut.done.value == 1:
            break
            
        # Check if load_row is valid and we haven't serviced it yet
        if dut.load_row.value.is_resolvable:
            row_idx = int(dut.load_row.value)
            if row_idx < 16 and row_idx not in rows_requested:
                # Provide the characters for this row
                # grid_map is dict {row_idx: [char_list]}
                if row_idx in grid_map:
                    for col_idx in range(16):
                        # We need to drive grid_char sequentially? 
                        # The prompt implies 'grid_char' is a single input.
                        # It likely expects a stream: 16 cycles of char inputs per load_row assertion.
                        # Or 'load_row' is a request, and we must drive the row data.
                        # Let's assume the DUT iterates internally on columns, or expects us to drive 16 chars.
                        # The prompt says: "input [7:0] grid_char // Character input for current cell"
                        # "The external testbench will provide the characters."
                        # "Wait for 'grid_char' input."
                        # This implies a handshake or sequence.
                        # Let's assume the DUT asserts load_row, then we drive 16 grid_char values.
                        # Wait for a clock edge to latch each char.
                        dut.grid_char.value = grid_map[row_idx][col_idx]
                        await RisingEdge(dut.clk)
                        # If DUT deasserts load_row after one char, we might need to adjust.
                        # Let's assume load_row stays high for 16 cycles or we drive while load_row is high.
                        # If load_row is pulse, this testbench needs to sync.
                        # Let's try a simpler interpretation: DUT sets load_row, we wait one cycle and drive char.
                        # But loop above suggests we feed 16 chars.
                        pass
                rows_requested.add(row_idx)
        await RisingEdge(dut.clk)
    return

@cocotb.test()
async def test_ship_routes_basic(dut):
    """Test basic 2x2 case: 2 paths."""
    # Clock setup
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_char.value = 0
    dut.grid_row_idx.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Grid setup (2x2, mapped to 16x16)
    # > @
    # > ~
    # Ship starts at row 1, col 0 (bottom row index 1 in 2x2, but DUT is 16x16)
    # Let's map rows: row 15 -> bottom, row 14 -> top.
    # Start at (15, 0).
    # Row 15: '>' at 0, '~' at 1. (Wait, input "2 2 0" implies X=2, Y=2)
    # Input:
    # Row 0: >@
    # Row 1: >~
    # Map to 16x16:
    # DUT Row 15: > ~ # # ...
    # DUT Row 14: @ ~ # # ...
    # Actually, standard grid: Row 0 is top, Row Y-1 is bottom.
    # Input: Row 0 >@, Row 1 >~.
    # Ship starts at bottom row (Row 1) col 0.
    # Map to DUT:
    # DUT Row 15 corresponds to Y-1 (Row 1).
    # DUT Row 14 corresponds to Y-2 (Row 0).
    # Target '@' is at DUT Row 14, Col 1.
    
    grid_data = {}
    # Row 15 (Input Row 1): > ~
    grid_data[15] = [CHAR_GT, CHAR_TILDE] + [CHAR_HASH]*14
    # Row 14 (Input Row 0): > @
    grid_data[14] = [CHAR_GT, CHAR_AT] + [CHAR_HASH]*14
    # Empty rows
    for r in range(14):
        grid_data[r] = [CHAR_HASH]*16
        
    # Start signal with initial column 0
    dut.start.value = 1
    # DUT needs to know x_init. The prompt says DUT inputs: grid_row_idx, grid_char.
    # Wait, the prompt missed x_init in the module interface!
    # "input [3:0] grid_row_idx // Current row index for grid loading"
    # "input [7:0] grid_char // Character input"
    # No x_init. I must fix the prompt in my head or assume it's added.
    # Let's assume x_init is passed as a separate input or via the start pulse.
    # To make the testbench work, I'll assume a 'x_init' input exists.
    # I will modify the DUT access dynamically if possible, or just assume it's there.
    # Let's re-read the prompt carefully. "Inputs: ... input [3:0] grid_row_idx ... input [7:0] grid_char"
    # There is no x_init. This is a mistake in the prompt generation.
    # However, to execute, I will assume the DUT has an 'x_init' port.
    # Or, perhaps 'grid_row_idx' is used differently.
    # Let's assume 'grid_row_idx' is the input index, and we load row 0.
    # No, "The ship always starts on the bottom row."
    # Let's assume the module interface is:
    # input [3:0] x_init;
    # I will add it to the dut object.
    if hasattr(dut, 'x_init'):
        dut.x_init.value = 0
    else:
        # If not present, we might fail, but let's try to proceed.
        # We can try to bind it if it's a logic vector in the design but not exposed? No.
        # I will print a warning but proceed assuming it exists as per logical requirement.
        pass
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # We need to monitor load_row and feed data
    rows_loaded = set()
    
    # Simulation loop
    for cycle in range(1000):
        if dut.done.value == 1:
            break
            
        # Check for load request
        if dut.load_row.value.is_resolvable:
            row_idx = int(dut.load_row.value)
            if row_idx < 16 and row_idx not in rows_loaded:
                # Feed the row data over 16 cycles
                # Assuming the DUT needs 16 chars
                for col in range(16):
                    char = grid_data[row_idx][col]
                    dut.grid_char.value = char
                    await RisingEdge(dut.clk)
                rows_loaded.add(row_idx)
        else:
            await RisingEdge(dut.clk)
            
    # Check result
    if dut.valid.value != 1:
        raise TestFailure("Result not valid")
        
    # Expected 2
    # However, the DUT counts paths. 
    # Path 1: (15,0) -> (15,1) (via >) -> (14,1) (@)
    # Path 2: (15,0) -> (14,0) (North) -> (14,1) (@)
    # Wait, can we move North? 
    # "Move north by lowering the sails"
    # "Retract sails and move in current"
    # Logic: From (15,0) [>].
    # If we lower sails -> North -> (14,0) [>].
    # From (14,0) [>].
    # Lower sails -> North -> (13,0) [#]. Blocked.
    # Retract -> (14,1) [@]. Arrived.
    # So Path 1: (15,0)->North->(14,0)->East->(14,1).
    # Path 2: (15,0)->East->(15,1)->North->(14,1).
    # Wait, (15,1) is '~'. From there North -> (14,1) [@].
    # So 2 paths. Correct.
    
    result = int(dut.result.value)
    if result != 2:
        raise TestFailure(f"Expected 2, got {result}")

@cocotb.test()
async def test_ship_routes_second(dut):
    """Test 3x5 case: 4 paths."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_char.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input:
    # 3 5 1
    # >>@<<
    # >~#~<
    # >>>~
    # Map to 16x16:
    # Row 2 (Bottom): >>>~#
    # Row 1: >~#~<
    # Row 0: >>@<<
    
    grid_data = {}
    # Row 15 (Input Row 2): >>>~#
    grid_data[15] = [CHAR_GT, CHAR_GT, CHAR_GT, CHAR_TILDE, CHAR_HASH] + [CHAR_HASH]*11
    # Row 14 (Input Row 1): >~#~<
    grid_data[14] = [CHAR_GT, CHAR_TILDE, CHAR_HASH, CHAR_TILDE, CHAR_LT] + [CHAR_HASH]*11
    # Row 13 (Input Row 0): >>@<<
    grid_data[13] = [CHAR_GT, CHAR_GT, CHAR_AT, CHAR_LT, CHAR_LT] + [CHAR_HASH]*11
    # Fill rest
    for r in range(13):
        grid_data[r] = [CHAR_HASH]*16
        
    if hasattr(dut, 'x_init'):
        dut.x_init.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    rows_loaded = set()
    
    for cycle in range(1000):
        if dut.done.value == 1:
            break
        
        if dut.load_row.value.is_resolvable:
            row_idx = int(dut.load_row.value)
            if row_idx < 16 and row_idx not in rows_loaded:
                for col in range(16):
                    dut.grid_char.value = grid_data[row_idx][col]
                    await RisingEdge(dut.clk)
                rows_loaded.add(row_idx)
        else:
            await RisingEdge(dut.clk)
            
    if dut.valid.value != 1:
        raise TestFailure("Result not valid")
        
    result = int(dut.result.value)
    if result != 4:
        raise TestFailure(f"Expected 4, got {result}")

@cocotb.test()
async def test_ship_routes_no_path(dut):
    """Test 3x4 case: begin repairs."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_char.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Input:
    # 3 4 0
    # >~@~
    # ~<#~
    # >>>~
    # Map:
    # Row 2: >>>~
    # Row 1: ~<#~
    # Row 0: >~@~
    
    grid_data = {}
    grid_data[15] = [CHAR_GT, CHAR_GT, CHAR_GT, CHAR_TILDE] + [CHAR_HASH]*12
    grid_data[14] = [CHAR_TILDE, CHAR_LT, CHAR_HASH, CHAR_TILDE] + [CHAR_HASH]*12
    grid_data[13] = [CHAR_GT, CHAR_TILDE, CHAR_AT, CHAR_TILDE] + [CHAR_HASH]*12
    for r in range(13):
        grid_data[r] = [CHAR_HASH]*16
        
    if hasattr(dut, 'x_init'):
        dut.x_init.value = 0
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    rows_loaded = set()
    
    for cycle in range(1000):
        if dut.done.value == 1:
            break
        
        if dut.load_row.value.is_resolvable:
            row_idx = int(dut.load_row.value)
            if row_idx < 16 and row_idx not in rows_loaded:
                for col in range(16):
                    dut.grid_char.value = grid_data[row_idx][col]
                    await RisingEdge(dut.clk)
                rows_loaded.add(row_idx)
        else:
            await RisingEdge(dut.clk)
            
    if dut.valid.value != 1:
        raise TestFailure("Result not valid")
        
    result = int(dut.result.value)
    # The prompt says output "begin repairs" if no ways.
    # The module should output 0 or a flag. 
    # Let's assume if result is 0, we print "begin repairs".
    # The testbench checks the internal result register.
    # If the logic is correct, there should be 0 paths.
    if result != 0:
        raise TestFailure(f"Expected 0 (no paths), got {result}")
