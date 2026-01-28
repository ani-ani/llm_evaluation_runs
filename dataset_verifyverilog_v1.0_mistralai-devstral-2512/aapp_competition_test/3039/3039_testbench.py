import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Convert 6x6 ASCII grid string to 36-bit integer
# Input string format: 6 lines of 6 chars (e.g., "......\n#.....\n...\n")
def grid_string_to_flat(grid_str):
    lines = grid_str.strip().split('\n')
    flat_val = 0
    bit_idx = 35  # MSB is top-left (0,0)
    for r in range(6):
        row = lines[r] if r < len(lines) else '.' * 6
        for c in range(6):
            char = row[c] if c < len(row) else '.'
            if char == '#':
                flat_val |= (1 << bit_idx)
            bit_idx -= 1
    return flat_val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_cube_fold(dut):
    # Setup Clock
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational, just wait for settle
        await Timer(100, units='ns')

    # Test cases: (Input String, Expected Result)
    # 1. Straight line (6 in a row) -> cannot fold
    # 2. Cross -> can fold
    # 3. T-shape -> can fold
    # 4. Zig-zag (6 connected, no 2x2) -> cannot fold
    test_cases = [
        ("......\n......\n######\n......\n......\n......\n", 0, "Straight line"),
        ("......\n#.....\n####..\n#.....\n......\n......\n", 1, "T-shape"),
        ("..##..\n...#..\n..##..\n...#..\n......\n......\n", 0, "Zig-zag 4 squares"),
        ("......\n...#..\n...#..\n..###.\n..#...\n......\n", 1, "T-shape variant"),
        (".#....\n###...\n.#....\n......\n......\n......\n", 0, "T-like but bent")
    ]

    for i, (grid_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running test {i+1}: {desc}")
        
        # Prepare input
        grid_flat = grid_string_to_flat(grid_str)
        
        # Drive Input
        if has_signal(dut, 'grid_flat'):
            dut.grid_flat.value = grid_flat
        else:
            # If interface uses individual bits or array, map here
            # For this spec, we assume 'grid_flat' vector exists
            # Fallback for array interface if spec changed:
            if has_signal(dut, 'grid'):
                for b in range(36):
                    dut.grid[b].value = (grid_flat >> (35-b)) & 1
            else:
                raise TestFailure("Interface 'grid_flat' not found")

        # Trigger
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done_seen = False
            for _ in range(100):  # Max wait cycles
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_seen = True
                    break
            
            if not done_seen:
                raise TestFailure(f"Timeout waiting for 'done' in test '{desc}'")
        else:
            # Combinational circuit
            await Timer(10, units='ns')

        # Check Result
        result_signal = dut.result if has_signal(dut, 'result') else None
        if result_signal is None:
            raise TestFailure("Output signal 'result' not found")
            
        actual = int(result_signal.value)
        if actual != expected:
            raise TestFailure(f"Test '{desc}' failed: Expected {expected}, got {actual}")
        
        cocotb.log.info(f"Test '{desc}' passed")
