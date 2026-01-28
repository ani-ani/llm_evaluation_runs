import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

# Testbench parameters
DATA_WIDTH = 8
TUPLE_SIZE = 2
NUM_TUPLES = 16
CLK_NS = 10
MAX_CYCLES = 1000

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_extract_freq(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Start clock
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        # (tuple_list, expected_count, description)
        ([(3, 4), (1, 2), (4, 3), (5, 6)], 3, "Basic test with duplicates"),
        ([(4, 15), (2, 3), (5, 4), (6, 7)], 4, "All unique tuples"),
        ([(5, 16), (2, 3), (6, 5), (6, 9)], 4, "Mix of orderings"),
        ([(1, 1), (1, 1), (1, 1)], 1, "All identical tuples"),
        ([(10, 20), (20, 10), (5, 5), (5, 5)], 2, "Two unique after sorting"),
        ([(1, 2)], 1, "Single tuple"),
        ([], 0, "Empty list (len=0)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (tuples, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Prepare input array with zeros
            input_arr = [[0, 0] for _ in range(NUM_TUPLES)]
            
            # Fill with test data
            for idx, (a, b) in enumerate(tuples):
                if idx < NUM_TUPLES:
                    input_arr[idx][0] = clamp_to_width(a, DATA_WIDTH)
                    input_arr[idx][1] = clamp_to_width(b, DATA_WIDTH)
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(len(tuples), 4)
            
            # Set array values
            # Method 1: If it's a 2D array
            if has_signal(dut, 'tuple_arr'):
                # Try accessing as 2D array
                for i_tup in range(NUM_TUPLES):
                    for i_elem in range(TUPLE_SIZE):
                        try:
                            # Attempt to access nested signal
                            sig = getattr(dut.tuple_arr[i_tup], f'_{i_elem}')
                            sig.value = input_arr[i_tup][i_elem]
                        except AttributeError:
                            try:
                                # Alternative: tuple_arr_{tup}_{elem}
                                sig = getattr(dut, f'tuple_arr_{i_tup}_{i_elem}')
                                sig.value = input_arr[i_tup][i_elem]
                            except AttributeError:
                                # Fallback: single flattened array
                                pass
            
            # Method 2: Flattened array tuple_arr_0_0, tuple_arr_0_1, etc.
            if NUM_TUPLES <= 8:
                for i_tup in range(NUM_TUPLES):
                    for i_elem in range(TUPLE_SIZE):
                        try:
                            sig = getattr(dut, f'tuple_arr_{i_tup}_{i_elem}')
                            sig.value = input_arr[i_tup][i_elem]
                        except AttributeError:
                            pass
            
            # Method 3: Alternative naming for 16 tuples
            if NUM_TUPLES == 16:
                # If it's a port array like arr_0, arr_1...
                all_named = True
                for i_tup in range(NUM_TUPLES):
                    for i_elem in range(TUPLE_SIZE):
                        try:
                            sig = getattr(dut, f'tuple_arr_{i_tup}_{i_elem}')
                            sig.value = input_arr[i_tup][i_elem]
                        except AttributeError:
                            all_named = False
                            break
                    if not all_named: break
                
                # If not all named, try packed representation
                if not all_named and has_signal(dut, 'tuple_arr'):
                    # Assume it's a packed 256-bit array: [31:0] for tuple 0, etc.
                    for i_tup in range(NUM_TUPLES):
                        packed_val = (input_arr[i_tup][1] << 8) | input_arr[i_tup][0]
                        try:
                            # Try accessing slice
                            dut.tuple_arr[i_tup*16 + 15 : i_tup*16].value = packed_val
                        except (AttributeError, TypeError):
                            # Try individual signal
                            pass
            
            # If sequential, trigger and wait
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                found_done = False
                for cycle in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        found_done = True
                        break
                
                if not found_done:
                    raise TestFailure(f"Timeout waiting for done signal")
            else:
                # Combinational: wait for result to settle
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Validate
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} - {desc}: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# Additional test for verifying sorting logic
cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_sorting_logic(dut):
    """Verify that tuples are correctly sorted internally"""
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test case: tuple (5, 1) should be sorted to (1, 5)
    # After deduplication, if (1,5) appears, it should match
    tuples = [(5, 1), (1, 5), (2, 2)]
    expected_unique = 2  # (1,5) and (2,2)
    
    if has_signal(dut, 'len'):
        dut.len.value = clamp_to_width(len(tuples), 4)
    
    # Set array
    input_arr = [[0, 0] for _ in range(NUM_TUPLES)]
    for idx, (a, b) in enumerate(tuples):
        input_arr[idx][0] = clamp_to_width(a, DATA_WIDTH)
        input_arr[idx][1] = clamp_to_width(b, DATA_WIDTH)
    
    # Set signals
    if NUM_TUPLES == 16:
        for i_tup in range(3):
            for i_elem in range(2):
                try:
                    sig = getattr(dut, f'tuple_arr_{i_tup}_{i_elem}')
                    sig.value = input_arr[i_tup][i_elem]
                except AttributeError:
                    # Try 2D access
                    try:
                        getattr(dut.tuple_arr[i_tup], f'_{i_elem}').value = input_arr[i_tup][i_elem]
                    except AttributeError:
                        pass
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        found = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                found = True
                break
        
        if not found:
            raise TestFailure("Timeout in sorting test")
    else:
        await Timer(100, units='ns')
    
    result = int(dut.result.value)
    if result != expected_unique:
        raise TestFailure(f"Sorting logic test failed: expected {expected_unique}, got {result}")
