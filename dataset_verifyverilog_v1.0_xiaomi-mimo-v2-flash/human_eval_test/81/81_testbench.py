import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

# --- Helper Functions ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_q88(f):
    """Convert float to Q8.8 integer (8 frac bits)"""
    return int(f * 256)

def unpack_grades(packed, num_grades):
    """Unpack 4-bit grades from 32-bit vector"""
    grades = []
    for i in range(num_grades):
        grade = (packed >> (i*4)) & 0xF
        grades.append(grade)
    return grades

GRADE_MAP = {
    0: 'A+',
    1: 'A',
    2: 'A-',
    3: 'B+',
    4: 'B',
    5: 'B-',
    6: 'C+',
    7: 'C',
    8: 'C-',
    9: 'D+',
    10: 'D',
    11: 'D',  # D- is 12, but Python spec shows >0.0 is D-, ==0.0 is E
    12: 'D-',
    13: 'E'
}

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_gpa_array(dut, gpas):
    """Write GPA floats into Q8.8 packed array"""
    # Convert to Q8.8 integers
    q88_vals = [float_to_q88(g) for g in gpas]
    # Pack into 64-bit vector
    packed = 0
    for i, val in enumerate(q88_vals):
        packed |= (clamp_to_width(val, 16) << (i * 16))
    
    # Assign to gpa_array (assumed as 8 separate 8-bit signals or packed)
    # We'll handle as packed 64-bit if exists, else individual
    if has_signal(dut, 'gpa_array'):
        # Assume it's a single 64-bit vector
        dut.gpa_array.value = packed
    else:
        # Fallback: try individual arr_0, arr_1...
        for i in range(ARRAY_SIZE):
            if has_signal(dut, f'gpa_array_{i}'):
                # Pack 2 grades per byte if 8-bit, or use 16-bit signals
                # For simplicity, assume 16-bit signals per grade if array size 8
                if has_signal(dut, 'gpa_array_0') and len(dut.gpa_array_0) == 16:
                    getattr(dut, f'gpa_array_{i}').value = clamp_to_width(q88_vals[i], 16)
                else:
                    getattr(dut, f'gpa_array_{i}').value = clamp_to_width(q88_vals[i] >> 8, 8)  # High byte
                    if i*2+1 < ARRAY_SIZE:
                        getattr(dut, f'gpa_array_{i*2+1}').value = clamp_to_width(q88_vals[i] & 0xFF, 8)  # Low byte

async def get_letter_grades(dut, num):
    """Read packed letter grades and decode"""
    if has_signal(dut, 'letter_grades'):
        packed = int(dut.letter_grades.value)
    else:
        # Try individual output ports
        packed = 0
        for i in range(num):
            if has_signal(dut, f'letter_grades_{i}'):
                grade = int(getattr(dut, f'letter_grades_{i}').value)
                packed |= (grade & 0xF) << (i * 4)
    return unpack_grades(packed, num)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_numerical_letter_grade(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([4.0, 3.0, 1.7, 2.0, 3.5], ['A+', 'B', 'C-', 'C', 'A-'], "Example 1"),
        ([1.2], ['D+'], "Example 2"),
        ([0.5], ['D-'], "Example 3"),
        ([0.0], ['E'], "Example 4"),
        ([1.0, 0.3, 1.5, 2.8, 3.3], ['D', 'D-', 'C-', 'B', 'B+'], "Example 5"),
        ([0.0, 0.7], ['E', 'D-'], "Example 6")
    ]
    
    passed = 0
    failed = 0
    
    for i, (gpas, expected_codes, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Map expected letter codes to expected ints
        expected_ints = []
        for code in expected_codes:
            for k, v in GRADE_MAP.items():
                if v == code:
                    expected_ints.append(k)
                    break
        
        try:
            if is_seq:
                dut.start.value = 1
                await write_gpa_array(dut, gpas)
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                if has_signal(dut, 'num_grades'):
                    dut.num_grades.value = len(gpas)
                
                await wait_for_done(dut)
            else:
                # Combinational
                await write_gpa_array(dut, gpas)
                if has_signal(dut, 'num_grades'):
                    dut.num_grades.value = len(gpas)
                await Timer(100, units='ns')
            
            result_ints = await get_letter_grades(dut, len(gpas))
            
            if result_ints != expected_ints:
                raise TestFailure(f"Expected {expected_codes} -> {expected_ints}, got {[GRADE_MAP[r] for r in result_ints]} -> {result_ints}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {expected_codes}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
