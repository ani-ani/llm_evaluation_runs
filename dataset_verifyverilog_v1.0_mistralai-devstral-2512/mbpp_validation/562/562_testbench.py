import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPERS
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_2d_array(dut, sublists, max_sublists=8, max_len=8, data_width=8):
    """Write test data to the 2D array structure"""
    # Initialize all elements to 0
    for i in range(max_sublists):
        # Set valid and lengths
        if has_signal(dut, f'valid_{i}'):
            getattr(dut, f'valid_{i}').value = 0
        elif has_signal(dut, 'valid'):
            dut.valid[i].value = 0
        
        if has_signal(dut, f'lengths_{i}'):
            getattr(dut, f'lengths_{i}').value = 0
        elif has_signal(dut, 'lengths'):
            dut.lengths[i].value = 0
        
        # Set array elements
        for j in range(max_len):
            if has_signal(dut, f'arr_{i}_{j}'):
                getattr(dut, f'arr_{i}_{j}').value = 0
            elif has_signal(dut, 'arr'):
                dut.arr[i][j].value = 0
    
    # Write actual test data
    for i, sublist in enumerate(sublists):
        if i >= max_sublists:
            break
        
        # Set valid bit
        is_valid = 1 if len(sublist) > 0 else 0
        if has_signal(dut, f'valid_{i}'):
            getattr(dut, f'valid_{i}').value = is_valid
        elif has_signal(dut, 'valid'):
            dut.valid[i].value = is_valid
        
        # Set length
        list_len = len(sublist)
        if has_signal(dut, f'lengths_{i}'):
            getattr(dut, f'lengths_{i}').value = clamp_to_width(list_len, 4)
        elif has_signal(dut, 'lengths'):
            dut.lengths[i].value = clamp_to_width(list_len, 4)
        
        # Set array elements (optional for this problem)
        for j, val in enumerate(sublist):
            if j >= max_len:
                break
            if has_signal(dut, f'arr_{i}_{j}'):
                getattr(dut, f'arr_{i}_{j}').value = clamp_to_width(val, data_width)
            elif has_signal(dut, 'arr'):
                dut.arr[i][j].value = clamp_to_width(val, data_width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_max_length(dut):
    # Setup
    CLK_NS = 10
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut, cycles=2)
    else:
        # Combinational circuit
        await Timer(100, units='ns')
    
    # Test cases from Python problem
    # Test 1: [[1],[1,4],[5,6,7,8]] -> max length 4
    # Test 2: [[0,1],[2,2,],[3,2,1]] -> max length 3
    # Test 3: [[7],[22,23],[13,14,15],[10,20,30,40,50]] -> max length 5
    
    test_cases = [
        (   # Test case 1
            [[1], [1, 4], [5, 6, 7, 8]],
            4,
            "Test 1: sublists of lengths 1,2,4"
        ),
        (   # Test case 2
            [[0, 1], [2, 2, 0], [3, 2, 1]],
            3,
            "Test 2: sublists of lengths 2,3,3"
        ),
        (   # Test case 3
            [[7], [22, 23], [13, 14, 15], [10, 20, 30, 40, 50]],
            5,
            "Test 3: sublists of lengths 1,2,3,5"
        ),
        (   # Edge case: empty sublists mixed with valid
            [[], [1,2,3], [4,5,6,7,8,9,10,11]],
            8,
            "Edge case: empty sublist, short list, long list (capped at 8)"
        ),
        (   # All same length
            [[1], [2], [3], [4], [5], [6], [7], [8]],
            1,
            "All single element sublists"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (sublists, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        cocotb.log.info(f"  Input: {sublists}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write test data
            await write_2d_array(dut, sublists)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=50)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            else:
                # Combinational: result should be available immediately
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} ✓")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"\nAll {passed} tests passed!")
