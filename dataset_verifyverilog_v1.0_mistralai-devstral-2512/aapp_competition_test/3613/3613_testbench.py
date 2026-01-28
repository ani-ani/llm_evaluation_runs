import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

DATA_WIDTH = 4
MAX_N = 16
CLK_NS = 10
MAX_CYCLES = 2000000  # 2^16 * 16 + overhead

def pack_pref_list(pref_lists, n):
    """Pack 16x16x4 bits into 256-bit integer for simulation"""
    packed = 0
    for i in range(MAX_N):
        for j in range(MAX_N):
            rank = pref_lists[i][j] if i < n and j < n else MAX_N - 1
            packed |= (rank & 0xF) << ((i * MAX_N + j) * 4)
    return packed

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def parse_input(input_str):
    lines = input_str.strip().split('\n')
    n = int(lines[0])
    current_teacher = [0] * MAX_N
    pref_lists = [[MAX_N - 1] * MAX_N for _ in range(MAX_N)]
    valid_kids = 0
    
    for i in range(n):
        parts = list(map(int, lines[i + 1].split()))
        teacher = parts[0]
        preferences = parts[1:]
        current_teacher[i] = teacher
        valid_kids |= (1 << i)
        for rank, kid in enumerate(preferences):
            pref_lists[i][kid - 1] = rank
    
    return n, current_teacher, pref_lists, valid_kids

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_kindergarten(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_inputs = [
        "6\n0 2 3 4 5 6\n0 1 3 4 5 6\n1 6 5 4 2 1\n2 6 5 3 2 1\n1 1 2 3 4 6\n2 1 2 3 4 5",
        "3\n0 2 3\n1 1 3\n2 1 2"
    ]
    expected_outputs = [4, 0]
    
    passed = failed = 0
    
    for test_idx, (input_str, expected_t) in enumerate(zip(test_inputs, expected_outputs)):
        cocotb.log.info(f"Test {test_idx + 1}: Expected T={expected_t}")
        
        n, teachers, prefs, valid_mask = parse_input(input_str)
        
        # Write inputs
        for i in range(MAX_N):
            dut.current_teacher[i].value = teachers[i]
            dut.valid_kids.value = valid_mask
            for j in range(MAX_N):
                dut.pref_list[i][j].value = prefs[i][j]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        try:
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            if not is_value_defined(dut.result_t.value):
                raise TestFailure("Result undefined")
            
            result_t = int(dut.result_t.value)
            found = int(dut.found.value) if has_signal(dut, 'found') else 1
            
            if found:
                if result_t != expected_t:
                    raise TestFailure(f"Expected T={expected_t}, got T={result_t}")
            else:
                # If no solution found but expected one, might still be correct for edge cases
                if expected_t != 15:
                    raise TestFailure(f"Expected T={expected_t}, but no solution found (found=0)")
            
            cocotb.log.info(f"  PASS: T={result_t}, found={found}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        await reset_dut(dut, cycles=5)
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")