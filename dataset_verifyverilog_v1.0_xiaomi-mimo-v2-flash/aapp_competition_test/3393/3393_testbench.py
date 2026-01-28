import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import itertools

DATA_WIDTH = 8
MAX_COURSES = 16
MAX_K = 8
CLK_NS = 10
MAX_CYCLES = 200

# Helpers from template

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
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if hasattr(dut, name):
            attr = getattr(dut, name)
            if i < len(attr):
                attr[i].value = clamp_to_width(v, width)

def python_solver(courses, k):
    """Python reference solver for comparison"""
    n = len(courses)
    # Parse courses
    course_data = []
    level1_map = {}
    level2_parent = {}
    
    for idx, (name, diff) in enumerate(courses):
        if name.endswith('1'):
            base = name[:-1]
            course_data.append((idx, diff, 'L1', base))
            level1_map[base] = idx
        elif name.endswith('2'):
            base = name[:-1]
            course_data.append((idx, diff, 'L2', base))
            # Will set parent later
        else:
            course_data.append((idx, diff, 'NL', name))
    
    # Set parents for L2
    parent = [-1] * n
    for idx, diff, typ, base in course_data:
        if typ == 'L2' and base in level1_map:
            parent[idx] = level1_map[base]
    
    # Generate all valid subsets of size k
    best = float('inf')
    valid_found = False
    
    for subset in itertools.combinations(range(n), k):
        subset_set = set(subset)
        valid = True
        total_diff = 0
        
        for idx in subset:
            if parent[idx] != -1 and parent[idx] not in subset_set:
                valid = False
                break
        
        if valid:
            for idx in subset:
                total_diff += courses[idx][1]
            if total_diff < best:
                best = total_diff
                valid_found = True
    
    return best if valid_found else 0

# Test data
test_cases = [
    {
        'name': 'Example 1: 5 courses, k=2',
        'courses': [
            ('linearalgebra', 10),
            ('calculus1', 10),
            ('calculus2', 20),
            ('honorsanalysis1', 50),
            ('honorsanalysis2', 100)
        ],
        'k': 2,
        'expected': 20  # linearalgebra + calculus1
    },
    {
        'name': 'Example 2: 7 courses, k=5',
        'courses': [
            ('introtocs', 40),
            ('algorithms1', 50),
            ('algorithms2', 200),
            ('datastructures', 120),
            ('theoryofcomputation', 200),
            ('machinelearning1', 100),
            ('machinelearning2', 50)
        ],
        'k': 5,
        'expected': 360
    },
    {
        'name': 'All standalone courses',
        'courses': [
            ('a', 5), ('b', 10), ('c', 15), ('d', 20),
            ('e', 25), ('f', 30), ('g', 35), ('h', 40)
        ],
        'k': 3,
        'expected': 5+10+15
    }
]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_course_selection(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for case in test_cases:
        courses = case['courses']
        k = case['k']
        expected = case['expected']
        name = case['name']
        
        n = len(courses)
        if n > MAX_COURSES:
            cocotb.log.info(f"Skipping {name}: too many courses ({n} > {MAX_COURSES})")
            continue
        
        cocotb.log.info(f"Testing: {name}")
        
        try:
            # Prepare data
            diff_list = [c[1] for c in courses]
            type_list = [0] * n  # 0:NoLevel, 1:LevelI, 2:LevelII
            parent_list = [0] * n  # Parent ID
            
            # Parse course names
            level1_map = {}
            for idx, (name_str, diff) in enumerate(courses):
                if name_str.endswith('1'):
                    base = name_str[:-1]
                    level1_map[base] = idx
                    type_list[idx] = 1  # LevelI
                elif name_str.endswith('2'):
                    base = name_str[:-1]
                    type_list[idx] = 2  # LevelII
                else:
                    type_list[idx] = 0  # NoLevel
            
            # Set parents for LevelII
            for idx, (name_str, diff) in enumerate(courses):
                if name_str.endswith('2'):
                    base = name_str[:-1]
                    if base in level1_map:
                        parent_list[idx] = level1_map[base]
            
            # Write inputs
            dut.n.value = n
            dut.k.value = k
            
            # Write arrays
            await write_array(dut, 'diff', diff_list, DATA_WIDTH)
            await write_array(dut, 'type', type_list, 2)
            await write_array(dut, 'parent', parent_list, 4)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Python verification
            py_result = python_solver(courses, k)
            
            cocotb.log.info(f"  HDL Result: {result}, Expected: {expected}, Python: {py_result}")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL ({name}): {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR ({name}): {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")