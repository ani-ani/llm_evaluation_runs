import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
ARRAY_SIZE = 8
DATA_WIDTH = 8
INDEX_WIDTH = 3
RESULT_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 200

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0:
        return 0
    if v > max_val:
        return max_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Reset helper
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'array_wr'):
        dut.array_wr.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Array loading helper
async def load_array(dut, values):
    """Load array values into dut.array_data at sequential addresses"""
    dut.array_wr.value = 1
    for addr in range(ARRAY_SIZE):
        if addr < len(values):
            val = clamp_to_width(values[addr], DATA_WIDTH)
            dut.array_data.value = val
            dut.array_addr.value = addr
        else:
            dut.array_data.value = 0
            dut.array_addr.value = addr
        await RisingEdge(dut.clk)
    dut.array_wr.value = 0
    await RisingEdge(dut.clk)

# Query processing helper
async def process_query(dut, left_idx, right_idx):
    """Process a single query and return result"""
    if has_signal(dut, 'start'):
        dut.query_l.value = clamp_to_width(left_idx, INDEX_WIDTH)
        dut.query_r.value = clamp_to_width(right_idx, INDEX_WIDTH)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Wait for done
    timeout = MAX_CYCLES
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            result = safe_int(dut.result.value)
            return result
    raise TestFailure(f"Timeout waiting for done signal")

# Magic subarray checker (reference implementation)
def check_magic_subarray(arr, l, r):
    """Reference: find longest magical subarray in arr[l:r+1]"""
    if l > r:
        return 0
    
    subarray = arr[l:r+1]
    n = len(subarray)
    if n == 0:
        return 0
    
    max_len = 1
    
    # Check all possible subarrays
    for i in range(n):
        for j in range(i, n):
            first = subarray[i]
            last = subarray[j]
            valid = True
            
            # Check if all elements between first and last are within range
            for k in range(i, j + 1):
                val = subarray[k]
                if val < min(first, last) or val > max(first, last):
                    valid = False
                    break
            
            if valid:
                length = j - i + 1
                max_len = max(max_len, length)
    
    return max_len

# Main testbench
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_magical_subarray(dut):
    """Test magical subarray query processing"""
    
    # Check if signals exist
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    has_result = has_signal(dut, 'result')
    has_array = has_signal(dut, 'array_data')
    has_array_addr = has_signal(dut, 'array_addr')
    has_array_wr = has_signal(dut, 'array_wr')
    has_query_l = has_signal(dut, 'query_l')
    has_query_r = has_signal(dut, 'query_r')
    
    if not all([has_done, has_result, has_array, has_array_addr, has_array_wr]):
        cocotb.log.error("Missing required signals")
        return
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            "array": [5, 4, 3, 3, 2],
            "queries": [
                (0, 1, 2),   # L=1,R=2 -> indices 0,1 -> [5,4]
                (1, 0, 0),   # L=1,R=1 -> [5]
                (2, 4, 3),   # L=2,R=4 -> indices 1,2,3 -> [4,3,3]
            ],
            "description": "Sample Input 1"
        },
        {
            "array": [6, 6, 5, 1, 6, 2],
            "queries": [
                (0, 4, 5, 2),  # L=4,R=5 -> [1,6]
                (1, 4, 5, 2),  # L=4,R=5 -> [1,6] (duplicate)
                (2, 1, 3, 4),  # L=1,R=4 -> [6,5,1,6]
            ],
            "description": "Sample Input 2"
        },
        {
            "array": [1, 2, 3, 4, 5],
            "queries": [
                (0, 0, 4, 5),  # Full array
                (1, 2, 3, 3),  # [3,4,5]
            ],
            "description": "Increasing sequence"
        },
        {
            "array": [5, 4, 3, 2, 1],
            "queries": [
                (0, 0, 4, 5),  # Full array
                (1, 2, 3, 3),  # [3,2,1]
            ],
            "description": "Decreasing sequence"
        },
    ]
    
    total_passed = 0
    total_failed = 0
    
    for test_case in test_cases:
        cocotb.log.info(f"\n{'='*50}")
        cocotb.log.info(f"Test Case: {test_case['description']}")
        cocotb.log.info(f"Array: {test_case['array']}")
        
        # Load array
        try:
            await load_array(dut, test_case['array'])
            cocotb.log.info("Array loaded successfully")
        except Exception as e:
            cocotb.log.error(f"Failed to load array: {e}")
            total_failed += 1
            continue
        
        # Process queries
        for q_idx, query_data in enumerate(test_case['queries']):
            if len(query_data) == 3:
                l, r, exp = query_data
                q_num = l + 1
            else:
                l, r, exp, _ = query_data
                q_num = l + 1
            
            cocotb.log.info(f"\nQuery {q_idx + 1}: L={q_num}, R={r + 1} (0-indexed: {l}:{r})")
            cocotb.log.info(f"Expected result: {exp}")
            
            try:
                if not has_query_l or not has_query_r:
                    raise TestFailure("Missing query index signals")
                
                result = await process_query(dut, l, r)
                
                # Calculate expected result
                expected = check_magic_subarray(test_case['array'], l, r)
                
                cocotb.log.info(f"Got result: {result}, Expected: {expected}")
                
                if result != expected:
                    raise TestFailure(f"Result mismatch: got {result}, expected {expected}")
                
                total_passed += 1
                cocotb.log.info(f"✓ Query passed")
                
            except TestFailure as e:
                cocotb.log.error(f"✗ Query failed: {e}")
                total_failed += 1
            except Exception as e:
                cocotb.log.error(f"✗ Unexpected error: {e}")
                total_failed += 1
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Total: {total_passed} passed, {total_failed} failed")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} test(s) failed")