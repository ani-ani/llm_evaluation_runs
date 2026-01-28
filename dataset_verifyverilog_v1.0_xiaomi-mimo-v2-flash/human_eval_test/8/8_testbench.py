import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
OUTPUT_WIDTH = 16
ARRAY_SIZE = 16
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
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def calculate_expected(numbers):
    """Calculate expected sum and product"""
    if not numbers:
        return 0, 1
    
    sum_val = 0
    prod_val = 1
    overflow = False
    
    for num in numbers:
        sum_val += num
        if not overflow:
            if prod_val * num > 0xFFFF:
                overflow = True
                prod_val = 0xFFFF
            else:
                prod_val *= num
    
    return clamp_to_width(sum_val, OUTPUT_WIDTH), prod_val

async def write_array_values(dut, values):
    """Write values to array elements individually"""
    for i in range(ARRAY_SIZE):
        val = values[i] if i < len(values) else 0
        # Access arr as array or individual ports
        if hasattr(dut, 'arr'):
            if i < len(values):
                dut.arr[i].value = clamp_to_width(val, DATA_WIDTH)
            else:
                dut.arr[i].value = 0
        else:
            # Handle separate arr_0, arr_1, ... naming
            port_name = f'arr_{i}'
            if hasattr(dut, port_name):
                if i < len(values):
                    getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
                else:
                    getattr(dut, port_name).value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_sum_product(dut):
    """Test sum_product module"""
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    
    # Test cases: (input_list, expected_sum, expected_prod, description)
    test_cases = [
        ([], 0, 1, "Empty list"),
        ([1, 1, 1], 3, 1, "Three ones"),
        ([100, 0], 100, 0, "With zero"),
        ([3, 5, 7], 15, 105, "Simple case"),
        ([10], 10, 10, "Single element"),
        ([15, 15, 15, 15, 15], 75, 759375, "Multiple elements"),  # 15^5 = 759375 > 0xFFFF
    ]
    
    passed = 0
    failed = 0
    
    for i, (numbers, exp_sum, exp_prod, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {numbers}")
        
        try:
            # Write array values
            await write_array_values(dut, numbers)
            
            # Write length
            dut.len.value = len(numbers)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, MAX_CYCLES)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read results
            if not is_value_defined(dut.sum_out.value):
                raise TestFailure("sum_out undefined")
            if not is_value_defined(dut.prod_out.value):
                raise TestFailure("prod_out undefined")
            
            result_sum = int(dut.sum_out.value)
            result_prod = int(dut.prod_out.value)
            
            # Check results
            if result_sum != exp_sum:
                raise TestFailure(f"Sum mismatch: expected {exp_sum}, got {result_sum}")
            if result_prod != exp_prod:
                raise TestFailure(f"Product mismatch: expected {exp_prod}, got {result_prod}")
            
            cocotb.log.info(f"  PASSED: sum={result_sum}, prod={result_prod}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            
        # Reset between tests for sequential logic
        if is_seq and i < len(test_cases) - 1:
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")