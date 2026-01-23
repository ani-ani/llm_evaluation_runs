import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

# Helper to encode grid to 32-bit hex
# R=00, G=01, B=10, Y=11
# Row major: Row 0 (bits 31:24) to Row 3 (bits 7:0)
def encode_grid(grid_str):
    lines = grid_str.strip().split('
')
    val = 0
    for r in range(4):
        for c in range(4):
            char = lines[r][c]
            if char == 'R': bits = 0
            elif char == 'G': bits = 1
            elif char == 'B': bits = 2
            elif char == 'Y': bits = 3
            else: bits = 0
            # Position: (3-r)*8 + (3-c)*2? No, let's stick to Row 0 at top bits.
            # Bits [31:24] = Row 0. Cell (0,0) is bits [31:30].
            shift = (3-r)*8 + (3-c)*2
            val |= (bits << shift)
    return val

@cocotb.test()
async def test_puzzle_solver(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_initial.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    test_cases = [
        ("RGGR
GBGB
BYBY
YRYR
", 3),
        ("RRRR
GBGG
GYBB
BYYY
", 4)
    ]
    
    for i, (grid_in, expected_moves) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: Input Grid
{grid_in}")
        
        encoded = encode_grid(grid_in)
        dut.grid_initial.value = encoded
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 5000:
                raise TestFailure(f"Test {i+1} timed out (likely stuck in loop)")
        
        result = int(dut.result.value)
        dut._log.info(f"Result: {result}, Expected: {expected_moves}, Cycles: {cycles}")
        
        if result != expected_moves:
            raise TestFailure(f"Test {i+1} failed! Got {result}, expected {expected_moves}")
            
    dut._log.info("All tests passed!")