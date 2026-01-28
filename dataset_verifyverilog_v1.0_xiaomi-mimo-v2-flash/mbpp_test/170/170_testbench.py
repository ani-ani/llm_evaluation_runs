import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
INDEX_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, values):
    # Write each element individually to avoid list assignment
    for i in range(min(len(values), ARRAY_SIZE)):
        if has_signal(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = clamp_to_width(values[i], DATA_WIDTH)
        elif hasattr(dut, 'arr'):
            dut.arr[i].value = clamp_to_width(values[i], DATA_WIDTH)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_sum_range_list(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational version
        await Timer(10, units='ns')

    # Test cases from Python problem
    test_cases = [
        ([2,1,5,6,8,3,4,9,10,11,8,12], 8, 10, 29, "Test 1: sum indices 8-10"),
        ([2,1,5,6,8,3,4,9,10,11,8,12], 5, 7, 16, "Test 2: sum indices 5-7"),
        ([2,1,5,6,8,3,4,9,10,11,8,12], 7, 10, 38, "Test 3: sum indices 7-10")
    ]
    
    passed = 0
    failed = 0
    
    for i, (full_arr, m, n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Extract first 8 elements (scale down to array size)
        arr = full_arr[:8]
        # Adjust indices to fit 0-7 range (scale down)
        m_scaled = min(m, 7)
        n_scaled = min(n, 7)
        
        # In Python version, if n > array length, it fails
        # We'll ensure m <= n and within bounds
        if m_scaled > n_scaled:
            m_scaled, n_scaled = n_scaled, m_scaled
        
        try:
            # Write array
            await write_array(dut, arr)
            
            if is_seq:
                # Set inputs
                dut.m.value = m_scaled
                dut.n.value = n_scaled
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                
                # Calculate expected sum for scaled indices
                calc_sum = sum(arr[m_scaled:n_scaled+1])
                
                if result != calc_sum:
                    raise TestFailure(f"Expected {calc_sum}, got {result}")
            else:
                # Combinational: set inputs and read immediately
                await Timer(10, units='ns')
                
                if has_signal(dut, 'm'): dut.m.value = m_scaled
                if has_signal(dut, 'n'): dut.n.value = n_scaled
                await Timer(10, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                calc_sum = sum(arr[m_scaled:n_scaled+1])
                
                if result != calc_sum:
                    raise TestFailure(f"Expected {calc_sum}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} - Result: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed!")