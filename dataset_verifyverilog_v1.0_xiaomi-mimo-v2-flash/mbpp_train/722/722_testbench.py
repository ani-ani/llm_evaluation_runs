import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 200

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

def float_to_q8_8(f):
    return int(f * 256)

def q8_8_to_float(v):
    return v / 256.0

def pack_student(name_str, height_f, weight_f):
    packed = 0
    # Pack name (5 chars + 3 padding)
    chars = list(name_str.ljust(5, ' '))
    for i in range(5):
        packed |= (ord(chars[i]) & 0xFF) << (32 - (i*8))
    # Pack height Q8.8
    height_fixed = float_to_q8_8(height_f)
    packed |= (height_fixed & 0xFFFF) << 16
    # Pack weight Q8.8
    weight_fixed = float_to_q8_8(weight_f)
    packed |= (weight_fixed & 0xFFFF)
    return packed

async def wait_for_done(dut, max_cycles=1000):
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

async def set_students(dut, students_list):
    for i, student in enumerate(students_list):
        packed = pack_student(student['name'], student['height'], student['weight'])
        dut.students[i].value = clamp_to_width(packed, 48)

async def set_thresholds(dut, min_h, min_w):
    dut.min_height.value = clamp_to_width(float_to_q8_8(min_h), 16)
    dut.min_weight.value = clamp_to_width(float_to_q8_8(min_w), 16)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_filter_students(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        {
            'students': [
                {'name': 'Cierra', 'height': 6.2, 'weight': 70},
                {'name': 'Alden', 'height': 5.9, 'weight': 65},
                {'name': 'Kierra', 'height': 6.0, 'weight': 68},
                {'name': 'Pierre', 'height': 5.8, 'weight': 66},
                {'name': 'Empty1', 'height': 5.0, 'weight': 50},
                {'name': 'Empty2', 'height': 5.0, 'weight': 50},
                {'name': 'Empty3', 'height': 5.0, 'weight': 50},
                {'name': 'Empty4', 'height': 5.0, 'weight': 50}
            ],
            'min_h': 6.0, 'min_w': 70,
            'expected_count': 1,
            'expected_flags': [1,0,0,0,0,0,0,0],
            'desc': 'Test 1: Cierra only'
        },
        {
            'students': [
                {'name': 'Cierra', 'height': 6.2, 'weight': 70},
                {'name': 'Alden', 'height': 5.9, 'weight': 65},
                {'name': 'Kierra', 'height': 6.0, 'weight': 68},
                {'name': 'Pierre', 'height': 5.8, 'weight': 66},
                {'name': 'Empty1', 'height': 5.0, 'weight': 50},
                {'name': 'Empty2', 'height': 5.0, 'weight': 50},
                {'name': 'Empty3', 'height': 5.0, 'weight': 50},
                {'name': 'Empty4', 'height': 5.0, 'weight': 50}
            ],
            'min_h': 5.9, 'min_w': 67,
            'expected_count': 2,
            'expected_flags': [1,0,1,0,0,0,0,0],
            'desc': 'Test 2: Cierra and Kierra'
        },
        {
            'students': [
                {'name': 'Cierra', 'height': 6.2, 'weight': 70},
                {'name': 'Alden', 'height': 5.9, 'weight': 65},
                {'name': 'Kierra', 'height': 6.0, 'weight': 68},
                {'name': 'Pierre', 'height': 5.8, 'weight': 66},
                {'name': 'Empty1', 'height': 5.0, 'weight': 50},
                {'name': 'Empty2', 'height': 5.0, 'weight': 50},
                {'name': 'Empty3', 'height': 5.0, 'weight': 50},
                {'name': 'Empty4', 'height': 5.0, 'weight': 50}
            ],
            'min_h': 5.7, 'min_w': 64,
            'expected_count': 4,
            'expected_flags': [1,1,1,1,0,0,0,0],
            'desc': 'Test 3: All four students'
        }
    ]
    
    passed = failed = 0
    
    for test_case in test_cases:
        cocotb.log.info(f"Running {test_case['desc']}")
        
        try:
            await set_students(dut, test_case['students'])
            await set_thresholds(dut, test_case['min_h'], test_case['min_w'])
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result_count.value):
                raise TestFailure("Result count undefined")
            
            result_count = int(dut.result_count.value)
            if result_count != test_case['expected_count']:
                raise TestFailure(f"Expected count {test_case['expected_count']}, got {result_count}")
            
            for i in range(ARRAY_SIZE):
                if has_signal(dut, f'filtered_{i}'):
                    flag_val = int(getattr(dut, f'filtered_{i}').value)
                else:
                    flag_val = int(dut.filtered[i].value)
                expected = test_case['expected_flags'][i]
                if flag_val != expected:
                    raise TestFailure(f"Student {i}: expected flag {expected}, got {flag_val}")
            
            passed += 1
            cocotb.log.info(f"PASS: {test_case['desc']}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {test_case['desc']} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    cocotb.log.info(f"All {passed} tests passed!")