import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CMD_DIST_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return max(0, min(max_val, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_turtle(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

    # Test cases
    test_cases = [
        # Case 1: 6x8, 5 commands
        {
            "h": 6, "w": 8, "n": 5,
            "grid": [
                "........", "...#....", "########",
                "#..#...#", "#..#####", "......."
            ],
            "cmds": [("up", 3), ("right", 7), ("down", 2), ("left", 4), ("up", 3)],
            "exp_min": 20, "exp_max": 20, "valid": 1
        },
        # Case 2: 6x8, 5 commands
        {
            "h": 6, "w": 8, "n": 5,
            "grid": [
                "........", "........", "###.####",
                "#......#", "#..#####", "......."
            ],
            "cmds": [("up", 3), ("right", 7), ("down", 2), ("left", 4), ("up", 3)],
            "exp_min": 17, "exp_max": 17, "valid": 1
        },
        # Case 3: 3x3 (mapped to 6x8 padded), 2 commands
        {
            "h": 3, "w": 3, "n": 2,
            "grid": [
                "...",
                ".#.",
                "..."
            ],
            "cmds": [("up", 2), ("right", 2)],
            "exp_min": 0, "exp_max": 0, "valid": 0  # -1 -1 maps to valid=0
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        # Map grid to 6x8 (row-major)
        grid_flat = []
        for r in range(6):
            row_str = ""
            if r < tc['h']:
                row_str = tc['grid'][r]
                if len(row_str) < 8:
                    row_str += "." * (8 - len(row_str))
            else:
                row_str = "." * 8
            for c in row_str:
                grid_flat.append(1 if c == '#' else 0)
        
        # Map commands (scale distances down if > 100 to fit 8-bit, but input guarantee allows 1-1M)
        # Assuming input distances are within reasonable range for 8-bit or need scaling logic.
        # For this test, we pass them directly (assuming < 256 or testbench logic handles scaling).
        # If distances > 255, we clamp (simplified logic).
        cmd_dirs = []
        cmd_dists = []
        dir_map = {"up": 0, "down": 1, "left": 2, "right": 3}
        for d, dist in tc['cmds']:
            cmd_dirs.append(dir_map[d])
            cmd_dists.append(clamp_to_width(dist, CMD_DIST_WIDTH))
        
        # Pad if fewer than 5 commands (standardized interface for this module spec)
        while len(cmd_dirs) < 5:
            cmd_dirs.append(0)
            cmd_dists.append(0)

        # Write inputs
        if has_signal(dut, 'target_grid'):
            # Handle as individual bits or packed array
            # Check if it's a single vector or multiple signals
            try:
                # Try packed vector first
                val = 0
                for idx, bit in enumerate(grid_flat):
                    if bit: val |= (1 << idx)
                dut.target_grid.value = val
            except Exception:
                # Try individual bits target_grid_0 ... target_grid_47
                for idx, bit in enumerate(grid_flat):
                    getattr(dut, f'target_grid_{idx}').value = bit
        
        if has_signal(dut, 'cmd_dir_0'):
            for i in range(5):
                getattr(dut, f'cmd_dir_{i}').value = cmd_dirs[i]
                getattr(dut, f'cmd_dist_{i}').value = cmd_dists[i]
        elif has_signal(dut, 'cmd_dir'):
             # Assuming array of structs is not standard Verilog, likely individual ports or packed
             pass

        # Start
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            found = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found = True
                    break
            if not found:
                raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        else:
            await Timer(100, units='ns')

        # Check results
        if not is_value_defined(dut.valid.value):
            raise TestFailure(f"Test {i+1}: Result valid undefined")
        
        valid_val = int(dut.valid.value)
        if valid_val != tc['valid']:
            raise TestFailure(f"Test {i+1}: Expected valid={tc['valid']}, got {valid_val}")
        
        if tc['valid'] == 1:
            min_val = int(dut.min_time.value)
            max_val = int(dut.max_time.value)
            if min_val != tc['exp_min'] or max_val != tc['exp_max']:
                raise TestFailure(f"Test {i+1}: Expected ({tc['exp_min']}, {tc['exp_max']}), got ({min_val}, {max_val})")
