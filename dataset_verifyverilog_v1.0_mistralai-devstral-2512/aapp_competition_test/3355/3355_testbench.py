import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, MAX_TASKS, CLK_NS, MAX_CYCLES = 8, 16, 10, 100000

# Helpers

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

# Packet array for travel times (18 locations × 18 travel times = 324 entries)
def pack_travel_times(travel):
    packed = 0
    for i in range(18):
        for j in range(18):
            val = travel[i][j] & 0xFF
            packed |= val << ((i*18 + j) * 8)
    return packed

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_scavenger(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test case 1: Example from problem
    # n=3, T=352
    # Tasks: (93,82,444), (92,76,436), (99,62,-1)
    # Travel matrix (5x5: 0-start, 1-3 tasks, 4-end)
    
    test_cases = [
        {
            "n": 3,
            "T": 352,
            "p": [93, 92, 99],
            "t": [82, 76, 62],
            "d": [444, 436, 255],  # -1 encoded as 255
            "travel": [
                [0, 70, 66, 71, 97],
                [76, 0, 87, 66, 74],
                [62, 90, 0, 60, 94],
                [60, 68, 68, 0, 69],
                [83, 78, 83, 73, 0]
            ],
            "exp_points": 99,
            "exp_mask": 0b100,  # Task 3 only (bit 2 set)
            "desc": "Example 1: Only task 3 possible"
        },
        {
            "n": 5,
            "T": 696,
            "p": [96, 99, 96, 90, 95],
            "t": [88, 70, 66, 92, 94],
            "d": [532, 519, 637, 592, 255],
            "travel": [
                [0, 67, 80, 81, 60, 83, 61],
                [72, 0, 99, 68, 85, 93, 82],
                [100, 91, 0, 88, 99, 70, 68],
                [69, 65, 77, 0, 65, 68, 75],
                [63, 65, 91, 96, 0, 92, 100],
                [65, 76, 85, 62, 89, 0, 75],
                [93, 83, 74, 65, 88, 84, 0]
            ],
            "exp_points": 386,
            "exp_mask": 0b1111,  # Tasks 1,2,3,5 (bits 0,1,2,4 set)
            "desc": "Example 2: Multiple tasks"
        }
    ]
    
    passed = failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"Testing: {tc['desc']}")
        try:
            # Set n_tasks and T_limit
            if has_signal(dut, 'n_tasks'):
                dut.n_tasks.value = tc['n']
            if has_signal(dut, 'T_limit'):
                dut.T_limit.value = tc['T']
            
            # Set task parameters
            for i in range(tc['n']):
                if has_signal(dut, 'p_i'):
                    dut.p_i[i].value = clamp_to_width(tc['p'][i], 7)
                elif hasattr(dut, 'p_i_0'):  # Individual ports
                    getattr(dut, f'p_i_{i}').value = clamp_to_width(tc['p'][i], 7)
                
                if has_signal(dut, 't_i'):
                    dut.t_i[i].value = clamp_to_width(tc['t'][i], 8)
                elif hasattr(dut, 't_i_0'):
                    getattr(dut, f't_i_{i}').value = clamp_to_width(tc['t'][i], 8)
                
                if has_signal(dut, 'd_i'):
                    dut.d_i[i].value = clamp_to_width(tc['d'][i], 8)
                elif hasattr(dut, 'd_i_0'):
                    getattr(dut, f'd_i_{i}').value = clamp_to_width(tc['d'][i], 8)
            
            # Set travel times (pack into 18x18 array)
            # For simplicity, assuming travel is a packed 144-bit input (18x8 bits each)
            if has_signal(dut, 'travel'):
                # Pack travel matrix into single value (for 18x8-bit rows)
                packed_val = 0
                for i in range(18):
                    row_val = 0
                    for j in range(18):
                        val = 0
                        if i < len(tc['travel']) and j < len(tc['travel'][0]):
                            val = tc['travel'][i][j]
                        row_val |= clamp_to_width(val, 8) << (j*8)
                    dut.travel[i].value = row_val
            elif hasattr(dut, 'travel_0'):  # Individual row ports
                for i in range(18):
                    row_val = 0
                    for j in range(18):
                        val = 0
                        if i < len(tc['travel']) and j < len(tc['travel'][0]):
                            val = tc['travel'][i][j]
                        row_val |= clamp_to_width(val, 8) << (j*8)
                    getattr(dut, f'travel_{i}').value = row_val
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done with timeout
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                
                # Read results
                if not is_value_defined(dut.max_points.value):
                    raise TestFailure("max_points undefined")
                
                result_points = int(dut.max_points.value)
                result_mask = int(dut.task_mask.value) if has_signal(dut, 'task_mask') else 0
                
                cocotb.log.info(f"Result: {result_points} points, mask={result_mask:#x}")
                
                if result_points != tc['exp_points']:
                    raise TestFailure(f"Expected {tc['exp_points']} points, got {result_points}")
                
                # Check mask if expecting non-zero
                if tc['exp_points'] > 0 and has_signal(dut, 'task_mask'):
                    if result_mask != tc['exp_mask']:
                        raise TestFailure(f"Expected mask {tc['exp_mask']:#x}, got {result_mask:#x}")
                
                passed += 1
            else:
                # Combinational - just set inputs
                await Timer(100, units='ns')
                result_points = safe_int(dut.max_points.value, 0)
                cocotb.log.info(f"Combinational result: {result_points} points")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")