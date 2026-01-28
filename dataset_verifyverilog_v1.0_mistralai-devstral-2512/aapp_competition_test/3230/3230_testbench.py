import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Helper to map char to byte value for the testbench
def grid_to_bytes(grid_str):
    # grid_str is list of strings, R lines, C chars each
    # We assume 8x8 for the testbench matching the spec
    flat_data = []
    for line in grid_str:
        for char in line:
            if char == 'X': flat_data.append(1)
            elif char == 'L': flat_data.append(2)
            else: flat_data.append(0)
    # Pad to 64 if smaller (though specs say R,C <= 100, test will be 8x8)
    while len(flat_data) < 64:
        flat_data.append(0)
    return flat_data[:64]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tram_explosions(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test Case 1 (Adapted to 8x8 concept)
    # Input 1 (4x4): .LX. / .X.. / .... / .L..
    # 8x8 Expansion (Top-Left corner):
    # 0: . L X . . . . .
    # 1: . X . . . . . .
    # 2: . . . . . . . .
    # 3: . L . . . . . .
    # ...
    grid1 = [
        ".LX......",
        ".X.......",
        ".........",
        ".L.......",
        ".........",
        ".........",
        ".........",
        "........."
    ]
    # Expected: 
    # X at (0,2), (1,1).
    # L at (0,1), (3,1).
    # Distance X(0,2) -> L(0,1): 1. X(0,2) -> L(3,1): 10.
    # Distance X(1,1) -> L(0,1): 1. X(1,1) -> L(3,1): 4.
    # Closest for L(0,1): X(0,2) dist 1, X(1,1) dist 1. Collision -> Explosion 1.
    # Closest for L(3,1): X(1,1) dist 4. (X(0,2) dist 10). No Collision.
    # Total: 1

    grid2 = [
        ".XLX....",
        ".X......",
        ".....L..",
        ".X......",
        ".........",
        ".........",
        ".........",
        "........."
    ]
    # Expected: 2

    test_cases = [
        (grid1, 1, "Sample 1"),
        (grid2, 2, "Sample 2")
    ]

    passed = 0
    failed = 0

    for grid, expected, desc in test_cases:
        cocotb.log.info(f"Running {desc}")
        data = grid_to_bytes(grid)
        
        # Write grid data
        # Spec: grid_data[63:0] is 64 bytes.
        # If it's a vector: dut.grid_data.value = packed_val
        # If individual signals: dut.grid_data_0.value = ...
        
        # We assume a packed 64*8 = 512 bit vector or array of 64 logic[7:0]
        # Implementation depends on Verilog module definition.
        # Let's assume dut.grid_data is a vector of 512 bits.
        # We need to pack it byte-wise.
        packed_val = 0
        for i, byte in enumerate(data):
            packed_val |= (byte & 0xFF) << (i * 8)
        
        if has_signal(dut, 'grid_data'):
            dut.grid_data.value = packed_val
        else:
            # Fallback for array logic if defined as dut.grid_data[i]
            for i, byte in enumerate(data):
                dut.grid_data[i].value = byte

        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        await wait_for_done(dut)

        if not is_value_defined(dut.explosions.value):
            cocotb.log.error(f"FAIL: {desc} - Result undefined")
            failed += 1
            continue

        result = int(dut.explosions.value)
        if result != expected:
            cocotb.log.error(f"FAIL: {desc} - Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: {desc} - Got {result}")
            passed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
