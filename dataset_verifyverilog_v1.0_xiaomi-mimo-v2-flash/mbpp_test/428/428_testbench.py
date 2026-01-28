import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def shell_sort_python(arr):
    """Python reference implementation of Shell sort"""
    gap = len(arr) // 2
    while gap > 0:
        for i in range(gap, len(arr)):
            current_item = arr[i]
            j = i
            while j >= gap and arr[j - gap] > current_item:
                arr[j] = arr[j - gap]
                j -= gap
            arr[j] = current_item
        gap //= 2
    return arr

async def write_array(dut, vals, width=8):
    """Write array values to dut data_in ports"""
    # Check if data_in is a bus or individual signals
    if has_signal(dut, 'data_in'):
        # Packed array - unpack and set
        total_bits = width * 16
        packed_val = 0
        for i, v in enumerate(vals):
            packed_val |= (clamp_to_width(v, width) << (i * width))
        dut.data_in.value = packed_val
    else:
        # Individual signals data_in_0, data_in_1, ...
        for i, v in enumerate(vals):
            sig_name = f'data_in_{i}'
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = clamp_to_width(v, width)
            else:
                raise TestFailure(f"Signal {sig_name} not found")

async def read_array(dut, width=8):
    """Read sorted array from dut data_out ports"""
    if has_signal(dut, 'data_out'):
        packed = int(dut.data_out.value)
        arr = []
        for i in range(16):
            val = (packed >> (i * width)) & ((1 << width) - 1)
            arr.append(val)
        return arr
    else:
        arr = []
        for i in range(16):
            sig_name = f'data_out_{i}'
            if has_signal(dut, sig_name):
                val = int(getattr(dut, sig_name).value)
                arr.append(val)
            else:
                raise TestFailure(f"Signal {sig_name} not found")
        return arr

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_shell_sort(dut):
    """Test Shell Sort module with various test cases"""
    
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=2)
    
    # Test cases (same as provided)
    test_cases = [
        ([12, 23, 4, 5, 3, 2, 12, 81, 56, 95, 0, 0, 0, 0, 0, 0], [2, 3, 4, 5, 12, 12, 23, 56, 81, 95, 0, 0, 0, 0, 0, 0]),
        ([24, 22, 39, 34, 87, 73, 68, 0, 0, 0, 0, 0, 0, 0, 0, 0], [22, 24, 34, 39, 68, 73, 87, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        ([32, 30, 16, 96, 82, 83, 74, 0, 0, 0, 0, 0, 0, 0, 0, 0], [16, 30, 32, 74, 82, 83, 96, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_arr, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {idx + 1}: Input = {input_arr[:10]}...")
        
        try:
            # Write input array
            await write_array(dut, input_arr)
            
            # Start sorting
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                # Combinational - just wait
                await Timer(100, units='ns')
            
            # Wait for done if sequential
            if has_signal(dut, 'done'):
                await wait_for_done(dut, max_cycles=10000)
            else:
                # Combinational - wait a bit for propagation
                await Timer(200, units='ns')
            
            # Read output
            result = await read_array(dut)
            
            # Log result
            cocotb.log.info(f"Result: {result[:10]}...")
            cocotb.log.info(f"Expected: {expected[:10]}...")
            
            # Check only non-zero elements (those from input)
            non_zero_input_len = len([x for x in input_arr if x > 0 or x == 0 and input_arr.index(x) < 7])
            if non_zero_input_len == 0:
                non_zero_input_len = 16
            
            # Verify sorted portion
            for i in range(non_zero_input_len):
                if result[i] != expected[i]:
                    raise TestFailure(f"Index {i}: expected {expected[i]}, got {result[i]}")
            
            # Verify remaining zeros
            for i in range(non_zero_input_len, 16):
                if result[i] != 0:
                    raise TestFailure(f"Index {i} should be 0, got {result[i]}")
            
            # Verify the result is actually sorted
            for i in range(1, non_zero_input_len):
                if result[i] < result[i-1]:
                    raise TestFailure(f"Result not sorted at index {i}: {result[i-1]} > {result[i]}")
            
            passed += 1
            cocotb.log.info(f"Test {idx + 1}: PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {idx + 1}: FAILED - {e}")
            failed += 1
    
    # Random tests
    random_tests = 3
    for r in range(random_tests):
        # Generate random array (some zeros, some values)
        input_arr = [random.randint(0, 255) for _ in range(7)] + [0] * 9
        expected = await shell_sort_python(input_arr[:7]) + [0] * 9
        
        cocotb.log.info(f"\nRandom Test {r + 1}: Input = {input_arr[:7]}...")
        
        try:
            await write_array(dut, input_arr)
            
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=10000)
            else:
                await Timer(200, units='ns')
            
            result = await read_array(dut)
            
            # Verify sorted
            for i in range(1, 7):
                if result[i] < result[i-1]:
                    raise TestFailure(f"Random test not sorted at {i}: {result[i-1]} > {result[i]}")
            
            # Verify zeros at end
            for i in range(7, 16):
                if result[i] != 0:
                    raise TestFailure(f"Random test: non-zero at end: {result[i]}")
            
            passed += 1
            cocotb.log.info(f"Random Test {r + 1}: PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"Random Test {r + 1}: FAILED - {e}")
            failed += 1
    
    # Final check: busy signal behavior
    if has_signal(dut, 'busy'):
        cocotb.log.info("\nTesting busy signal behavior...")
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        if int(dut.busy.value) != 1:
            cocotb.log.warning("Busy signal not high after start")
        
        await wait_for_done(dut, max_cycles=10000)
        
        if int(dut.busy.value) != 0:
            cocotb.log.warning("Busy signal not low after done")
    
    # Summary
    total = passed + failed
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Total tests: {total}")
    cocotb.log.info(f"Passed: {passed}")
    cocotb.log.info(f"Failed: {failed}")
    cocotb.log.info(f"{'='*50}")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {total} tests failed")