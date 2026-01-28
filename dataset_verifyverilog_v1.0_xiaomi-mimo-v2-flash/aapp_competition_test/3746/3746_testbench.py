import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 16, 9, 10, 200

# MANDATORY HELPERS
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# ARRAY ACCESS HELPERS
def pack_matrix(matrix, bits=16):
    """Pack 3x3 matrix into 9x16 bits"""
    packed = 0
    for i in range(3):
        for j in range(3):
            idx = i * 3 + j
            packed |= (matrix[i][j] & ((1 << bits) - 1)) << (idx * bits)
    return packed

async def set_cost_matrix(dut, matrix):
    """Set 3x3 cost matrix from Python 2D list"""
    # Pack the matrix and assign to port if exists
    packed = pack_matrix(matrix)
    if has_signal(dut, 'cost_in'):
        dut.cost_in.value = packed
    else:
        # Individual ports cost_0_0, cost_0_1...
        for i in range(3):
            for j in range(3):
                port_name = f'cost_{i}_{j}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(matrix[i][j], 16)
                elif has_signal(dut, 'cost_in'):
                    # Already handled above
                    pass
                else:
                    # Fallback: assume packed array structure
                    pass

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_smally_hanoi(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem statement
    test_cases = [
        ({"matrix": [[0,1,1],[1,0,1],[1,1,0]], "n": 3}, 7, "3 disks, symmetric costs"),
        ({"matrix": [[0,2,2],[1,0,100],[1,2,0]], "n": 3}, 19, "3 disks, asymmetric costs"),
        ({"matrix": [[0,2,1],[1,0,100],[1,2,0]], "n": 5}, 87, "5 disks, asymmetric costs"),
        ({"matrix": [[0,5835,1487],[6637,0,9543],[6961,6820,0]], "n": 7}, 723638, "7 disks, larger costs"),
        ({"matrix": [[0,1,1],[1,0,1],[1,1,0]], "n": 1}, 1, "1 disk, basic case"),
        ({"matrix": [[0,1,10],[1,0,1],[10,1,0]], "n": 1}, 1, "1 disk, asymmetric direct cost"),
        ({"matrix": [[0,1,100],[1,0,1],[100,1,0]], "n": 1}, 1, "1 disk, expensive direct move"),
    ]
    
    passed = failed = 0
    
    for i, (input_data, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            matrix = input_data["matrix"]
            n = input_data["n"]
            
            # Set cost matrix
            await set_cost_matrix(dut, matrix)
            
            # Set n
            if has_signal(dut, 'n'):
                dut.n.value = n
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed: raise TestFailure(f"{failed} tests failed")