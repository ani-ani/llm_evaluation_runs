import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 4
CLK_NS = 10
MAX_CYCLES = 100

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_sublists(dut, sublists, valid_mask):
    """Write sublists to 2D array format"""
    flat = []
    for i in range(4):
        for j in range(4):
            if i < len(sublists) and j < len(sublists[i]):
                flat.append(clamp_to_width(sublists[i][j], DATA_WIDTH))
            else:
                flat.append(0)
    
    # Individual assignment to avoid list assignment
    for idx, val in enumerate(flat):
        y = idx // 4  # sublist index
        x = idx % 4   # element index
        attr = f'sublists_{y}_{x}'
        getattr(dut, attr).value = val
    
    dut.valid_mask.value = valid_mask

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_length(dut):
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module missing clk signal")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        {
            'sublists': [[0], [1, 3], [5, 7], [9, 11]],
            'valid_mask': 0b1111,
            'exp_length': 2,
            'exp_sublist': [5, 7, 0, 0],
            'desc': 'Equal max lengths, tie-break by value'
        },
        {
            'sublists': [[1], [5, 7], [10, 12, 14, 15]],
            'valid_mask': 0b0111,
            'exp_length': 4,
            'exp_sublist': [10, 12, 14, 15],
            'desc': 'Clear maximum length'
        },
        {
            'sublists': [[5], [15, 20, 25]],
            'valid_mask': 0b0011,
            'exp_length': 3,
            'exp_sublist': [15, 20, 25, 0],
            'desc': 'Short list with padding'
        },
        {
            'sublists': [[0, 0, 0, 0], [1, 2, 3, 0], [4, 5, 6, 7]],
            'valid_mask': 0b0111,
            'exp_length': 4,
            'exp_sublist': [4, 5, 6, 7],
            'desc': 'Zero padding test'
        }
    ]
    
    passed = failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {tc['desc']}")
        try:
            await write_sublists(dut, tc['sublists'], tc['valid_mask'])
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.max_length.value):
                raise TestFailure("max_length undefined")
            
            result_len = int(dut.max_length.value)
            if result_len != tc['exp_length']:
                raise TestFailure(f"Length mismatch: expected {tc['exp_length']}, got {result_len}")
            
            result_sublist = []
            for idx in range(4):
                attr = f'max_sublist_{idx}'
                if not has_signal(dut, attr):
                    raise TestFailure(f"Missing max_sublist_{idx}")
                val = int(getattr(dut, attr).value)
                result_sublist.append(val)
            
            for j, (got, exp) in enumerate(zip(result_sublist, tc['exp_sublist'])):
                if got != exp:
                    raise TestFailure(f"Sublist[{j}]: expected {exp}, got {got}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")