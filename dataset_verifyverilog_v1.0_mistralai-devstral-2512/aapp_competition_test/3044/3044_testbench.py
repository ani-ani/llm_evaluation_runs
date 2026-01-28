import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except: return False

# Grid and String Packing
def pack_grid(grid_str):
    # grid_str is 3 lines of 8 chars (8x8 grid assumed for test, padding if needed)
    # S=0x53, G=0x47, #=0x23, .=0x2E
    lines = grid_str.strip().split('\n')
    packed = 0
    for r in range(8):
        row = lines[r] if r < len(lines) else '.'*8
        for c in range(8):
            char = row[c] if c < len(row) else '.'
            val = ord(char)
            packed |= val << ((r*8 + c) * 8)
    return packed

def pack_cmd(cmd_str):
    # cmd_str length <= 16
    # L=0x4C, R=0x52, U=0x55, D=0x44
    packed = 0
    for i, c in enumerate(cmd_str):
        val = ord(c)
        packed |= val << (i * 8)
    return packed

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_robot_path_fixer(dut):
    # Setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        # Input 1
        {
            "grid": "3 3\nS..\n.#.\n..G\n",
            "cmd": "DRRDD",
            "expected": 1
        },
        # Input 2
        {
            "grid": "3 7\n.......\n.G.#.S.\n.......\n",
            "cmd": "LDLDLLDR",
            "expected": 1
        },
        # Input 3
        {
            "grid": "3 7\n.#.....\n.G.##S.\n.......\n",
            "cmd": "LDLDLLDR",
            "expected": 2
        },
        # Input 4
        {
            "grid": "2 4\nS.#.\n#..G\n",
            "cmd": "RRUUDDRRUUUU",
            "expected": 0
        }
    ]

    for i, tc in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}")
        
        # Prepare Inputs
        # Pad grid to 8x8 for the packing function
        h, w = map(int, tc['grid'].split()[0:2])
        grid_lines = tc['grid'].split('\n')[1:1+h]
        padded_grid = ""
        for line in grid_lines:
            padded_grid += line + '.' * (8 - len(line))
        for _ in range(8 - h):
            padded_grid += '.' * 8
            
        grid_packed = pack_grid(padded_grid)
        cmd_packed = pack_cmd(tc['cmd'])
        cmd_len = len(tc['cmd'])
        
        # Assign to DUT
        dut.grid.value = grid_packed
        dut.cmd_str.value = cmd_packed
        dut.cmd_len.value = cmd_len
        
        if has_signal(dut, 'clk'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done_seen = False
            for _ in range(5000): # Large timeout for DP
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_seen = True
                    break
            
            if not done_seen:
                raise TestFailure(f"Test {i+1} Timeout: Done signal not asserted")
        else:
            await Timer(100, units='ns')
            
        result = int(dut.result.value)
        dut._log.info(f"Test {i+1}: Expected {tc['expected']}, Got {result}")
        
        if result != tc['expected']:
            raise TestFailure(f"Test {i+1} Failed: Expected {tc['expected']}, Got {result}")
