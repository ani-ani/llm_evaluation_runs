import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
DATA_WIDTH = 8
ARRAY_SIZE = 4
CLK_NS = 10
MAX_CYCLES = 1000

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(1, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'clk'):
        for _ in range(cycles): await RisingEdge(dut.clk)
    else:
        await Timer(cycles * CLK_NS, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

def encode_char(c):
    return ord(c) & 0xFF

def char_to_str(val):
    return chr(val)

# Generate expected combinations for n elements
from itertools import combinations

def get_expected_combinations(elements, n):
    indices = list(range(n))
    result = []
    # Generate all subsets in binary order (lexicographic by bit count)
    for i in range(1 << n):
        subset = []
        for j in range(n):
            if i & (1 << j):
                subset.append(elements[j])
        result.append(subset)
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_combinations(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ('Test 1: 4 elements', ['r', 'g', 'b', 'w'], 4),
        ('Test 2: 3 elements', ['r', 'g', 'b'], 3),
        ('Test 3: 2 elements', ['r', 'g'], 2),
        ('Test 4: 1 element', ['r'], 1),
        ('Test 5: 0 elements', [], 0)
    ]
    
    passed = 0
    failed = 0
    
    for test_name, elements, n in test_cases:
        cocotb.log.info(f"Testing {test_name}")
        try:
            expected = get_expected_combinations(elements, n)
            num_combinations = 1 << n
            
            # Reset result collection
            observed = []
            
            if is_seq:
                # Set inputs
                dut.len.value = n
                for i in range(ARRAY_SIZE):
                    getattr(dut, f'elements_in_{i}').value = 0
                for i, el in enumerate(elements):
                    getattr(dut, f'elements_in_{i}').value = encode_char(el)
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Collect outputs
                for _ in range(num_combinations + 2):  # +2 for cycles after start
                    await RisingEdge(dut.clk)
                    
                    if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                        # Read result
                        cur_len = safe_int(dut.result_len.value, 0)
                        cur_result = []
                        for i in range(ARRAY_SIZE):
                            if i < cur_len:
                                val = safe_int(getattr(dut, f'result_{i}').value, 0)
                                if val != 0:
                                    cur_result.append(chr(val))
                                else:
                                    cur_result.append(chr(0))
                        observed.append(cur_result)
                
                # Wait for done
                if has_signal(dut, 'done'):
                    await wait_for_done(dut)
                
            else:
                # Combinational logic test
                dut.len.value = n
                for i in range(ARRAY_SIZE):
                    getattr(dut, f'elements_in_{i}').value = 0
                for i, el in enumerate(elements):
                    getattr(dut, f'elements_in_{i}').value = encode_char(el)
                await Timer(100, units='ns')
                
                # Check single output
                if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                    cur_len = safe_int(dut.result_len.value, 0)
                    cur_result = []
                    for i in range(ARRAY_SIZE):
                        if i < cur_len:
                            val = safe_int(getattr(dut, f'result_{i}').value, 0)
                            if val != 0:
                                cur_result.append(chr(val))
                    observed.append(cur_result)
            
            # Validate observed vs expected
            if n == 0:
                # Special case: 1 combination of empty list
                if len(observed) != 1 or observed[0] != []:
                    raise TestFailure(f"Expected [[]], got {observed}")
            else:
                if len(observed) != len(expected):
                    raise TestFailure(f"Expected {len(expected)} combinations, got {len(observed)}")
                
                for i, (obs, exp) in enumerate(zip(observed, expected)):
                    if obs != exp:
                        raise TestFailure(f"Combination {i}: expected {exp}, got {obs}")
            
            cocotb.log.info(f"PASS: {test_name}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL {test_name}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")

# Additional test for exact Python examples
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_python_examples(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test 1: ['orange', 'red', 'green', 'blue'] -> sorted order
    elements = ['o', 'r', 'g', 'b']  # Using first char for 8-bit encoding
    n = 4
    
    if is_seq:
        dut.len.value = n
        for i in range(ARRAY_SIZE):
            getattr(dut, f'elements_in_{i}').value = 0
        for i, el in enumerate(elements):
            getattr(dut, f'elements_in_{i}').value = encode_char(el)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        observed = []
        for _ in range(18):  # 2^4 + 2
            await RisingEdge(dut.clk)
            if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                cur_len = safe_int(dut.result_len.value, 0)
                cur_result = []
                for i in range(ARRAY_SIZE):
                    if i < cur_len:
                        val = safe_int(getattr(dut, f'result_{i}').value, 0)
                        if val != 0:
                            cur_result.append(chr(val))
                observed.append(cur_result)
        
        # Expected pattern (binary order)
        expected = [
            [],
            ['o'],
            ['r'],
            ['r', 'o'],
            ['g'],
            ['g', 'o'],
            ['g', 'r'],
            ['g', 'r', 'o'],
            ['b'],
            ['b', 'o'],
            ['b', 'r'],
            ['b', 'r', 'o'],
            ['b', 'g'],
            ['b', 'g', 'o'],
            ['b', 'g', 'r'],
            ['b', 'g', 'r', 'o']
        ]
        
        if len(observed) != len(expected):
            raise TestFailure(f"Expected {len(expected)} combinations, got {len(observed)}")
        
        for i, (obs, exp) in enumerate(zip(observed, expected)):
            if obs != exp:
                raise TestFailure(f"Combination {i}: expected {exp}, got {obs}")
        
        cocotb.log.info("PASS: Python example 1")
    else:
        # Combinational test
        dut.len.value = n
        for i in range(ARRAY_SIZE):
            getattr(dut, f'elements_in_{i}').value = 0
        for i, el in enumerate(elements):
            getattr(dut, f'elements_in_{i}').value = encode_char(el)
        await Timer(100, units='ns')
        cocotb.log.info("Combinational module tested")