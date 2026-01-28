import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 2      # 2 bits for 0-3 (0=white, 1-3=colors)
N = 3               # Canvas size 3x3
MAX_SAVES = 2       # Maximum save slots
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def send_command(dut, cmd_type, paint_color=None, x1=None, y1=None, x2=None, y2=None, load_idx=None):
    """Send a command to the DUT and wait for completion."""
    # Set command type
    dut.cmd_type.value = cmd_type
    
    # Set command-specific inputs
    if cmd_type == 0:  # PAINT
        if None in [paint_color, x1, y1, x2, y2]:
            raise ValueError("PAINT command requires all parameters")
        dut.paint_color.value = paint_color
        dut.x1.value = x1
        dut.y1.value = y1
        dut.x2.value = x2
        dut.y2.value = y2
    elif cmd_type == 2:  # LOAD
        if load_idx is None:
            raise ValueError("LOAD command requires load_idx")
        dut.load_idx.value = load_idx
    # For SAVE, no extra inputs needed
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    await wait_for_done(dut)
    await RisingEdge(dut.clk)  # Allow outputs to stabilize

# ============================================================================
# CANVAS READING
# ============================================================================

async def read_canvas(dut):
    """Read current canvas state and convert to 1-indexed colors."""
    canvas = []
    for i in range(N):
        row = []
        for j in range(N):
            if is_value_defined(dut.canvas[i][j].value):
                val = int(dut.canvas[i][j].value)
                # Convert stored value (0=white) to output color (1=white)
                row.append(val + 1)
            else:
                row.append(None)
        canvas.append(row)
    return canvas

def print_canvas(canvas, test_name):
    """Print canvas in testbench log."""
    cocotb.log.info(f"Canvas after {test_name}:")
    for row in canvas:
        cocotb.log.info("  " + " ".join(str(x) if x is not None else "X" for x in row))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_drawing_engine(dut):
    """Test drawing engine with PAINT, SAVE, and LOAD commands."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Helper to verify canvas
    async def verify_canvas(expected, test_name):
        canvas = await read_canvas(dut)
        print_canvas(canvas, test_name)
        for i in range(N):
            for j in range(N):
                if canvas[i][j] != expected[i][j]:
                    raise TestFailure(f"Cell ({i},{j}) expected {expected[i][j]}, got {canvas[i][j]}")
    
    # TEST 1: Two PAINT commands (scaled first example)
    dut._log.info("\n" + "="*60)
    dut._log.info("TEST 1: PAINT 2 0 0 2 2, then PAINT 3 0 2 2 2")
    dut._log.info("="*60)
    
    # PAINT 2 0 0 2 2 -> color=2-1=1
    await send_command(dut, cmd_type=0, paint_color=1, x1=0, y1=0, x2=2, y2=2)
    
    # PAINT 3 0 2 2 2 -> color=3-1=2
    await send_command(dut, cmd_type=0, paint_color=2, x1=0, y1=2, x2=2, y2=2)
    
    # Expected: [2,1,3], [1,2,1], [2,1,3]
    expected_1 = [
        [2, 1, 3],
        [1, 2, 1],
        [2, 1, 3]
    ]
    await verify_canvas(expected_1, "TEST1 final")
    dut._log.info("TEST 1 PASSED")
    
    # Reset for next test
    await reset_dut(dut)
    
    # TEST 2: PAINT, SAVE, PAINT, LOAD (second example)
    dut._log.info("\n" + "="*60)
    dut._log.info("TEST 2: PAINT 3 0 0 1 1, SAVE, PAINT 2 1 1 2 2, LOAD 1")
    dut._log.info("="*60)
    
    # PAINT 3 0 0 1 1 -> color=3-1=2
    await send_command(dut, cmd_type=0, paint_color=2, x1=0, y1=0, x2=1, y2=1)
    
    # SAVE
    await send_command(dut, cmd_type=1)
    
    # PAINT 2 1 1 2 2 -> color=2-1=1
    await send_command(dut, cmd_type=0, paint_color=1, x1=1, y1=1, x2=2, y2=2)
    
    # LOAD 1
    await send_command(dut, cmd_type=2, load_idx=1)
    
    # Expected: [3,1,1], [1,3,1], [1,1,1]
    expected_2 = [
        [3, 1, 1],
        [1, 3, 1],
        [1, 1, 1]
    ]
    await verify_canvas(expected_2, "TEST2 final")
    dut._log.info("TEST 2 PASSED")
    
    # Reset for next test
    await reset_dut(dut)
    
    # TEST 3: Complex sequence (third example)
    dut._log.info("\n" + "="*60)
    dut._log.info("TEST 3: PAINT 2 0 0 1 1, SAVE, PAINT 3 1 1 2 2, SAVE, PAINT 4 0 2 0 2, LOAD 2, PAINT 4 2 0 2 0")
    dut._log.info("="*60)
    
    # PAINT 2 0 0 1 1 -> color=2-1=1
    await send_command(dut, cmd_type=0, paint_color=1, x1=0, y1=0, x2=1, y2=1)
    
    # SAVE (save #1)
    await send_command(dut, cmd_type=1)
    
    # PAINT 3 1 1 2 2 -> color=3-1=2
    await send_command(dut, cmd_type=0, paint_color=2, x1=1, y1=1, x2=2, y2=2)
    
    # SAVE (save #2)
    await send_command(dut, cmd_type=1)
    
    # PAINT 4 0 2 0 2 -> color=4-1=3
    await send_command(dut, cmd_type=0, paint_color=3, x1=0, y1=2, x2=0, y2=2)
    
    # LOAD 2
    await send_command(dut, cmd_type=2, load_idx=2)
    
    # PAINT 4 2 0 2 0 -> color=4-1=3
    await send_command(dut, cmd_type=0, paint_color=3, x1=2, y1=0, x2=2, y2=0)
    
    # Expected: [2,1,1], [1,3,1], [4,1,3]
    expected_3 = [
        [2, 1, 1],
        [1, 3, 1],
        [4, 1, 3]
    ]
    await verify_canvas(expected_3, "TEST3 final")
    dut._log.info("TEST 3 PASSED")
    
    # Summary
    dut._log.info("\n" + "="*60)
    dut._log.info("ALL TESTS PASSED")
    dut._log.info("="*60)
