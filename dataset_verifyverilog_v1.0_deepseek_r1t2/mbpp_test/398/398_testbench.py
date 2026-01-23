import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST HELPER: Compute expected result
# ============================================================================

def compute_expected(test_data):
    total = 0
    def process(item):
        nonlocal total
        if isinstance(item, list):
            for sub in item:
                process(sub)
        elif isinstance(item, str):
            for char in item:
                if char.isdigit():
                    total += int(char)
        else:
            num = int(item)
            for digit in str(abs(num)):
                total += int(digit)
    if isinstance(test_data, list):
        for item in test_data:
            process(item)
    else:
        process(test_data)
    return total

def flatten_and_pad(test_data):
    flat = []
    def flatten(item):
        if isinstance(item, list):
            for sub in item:
                flatten(sub)
        elif isinstance(item, str):
            for char in item:
                if char.isdigit():
                    flat.append(int(char))
                elif char.isalpha():
                    flat.append(ord(char) % 128)
        else:
            flat.append(int(item))
    flatten(test_data)
    if len(flat) > 8:
        flat = flat[:8]
    elif len(flat) < 8:
        flat.extend([0] * (8 - len(flat)))
    return flat

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sum_of_digits(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([10, 2, 56], "Test 1"),
        ([[10, 20, 4, 5, 'b', 70, 'a']], "Test 2"),
        ([10, 20, -4, 5, -70], "Test 3"),
        ([0, 0, 0, 0], "Edge: All zeros"),
        ([255, 123, 45], "Edge: Large numbers"),
        ([-1, -2, -3], "Edge: Negative numbers"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_data, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            input_values = flatten_and_pad(test_data)
            expected_sum = compute_expected(test_data)
            
            cocotb.log.info(f"  Input: {input_values[:sum(1 for x in input_values if x != 0)]} (showing non-zero)")
            cocotb.log.info(f"  Expected: {expected_sum}")
            
            # Write to individual ports
            for idx in range(8):
                val = input_values[idx]
                if val < 0:
                    val_unsigned = from_signed(val, 8)
                else:
                    val_unsigned = clamp_to_width(val, 8)
                
                port_name = f"arr_{idx}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = val_unsigned
                else:
                    raise TestFailure(f"Port {port_name} not found")
            
            # Write length
            valid_len = sum(1 for x in input_values if x != 0)
            if valid_len == 0:
                valid_len = 1
            dut.len.value = valid_len
            
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if result != expected_sum:
                raise TestFailure(f"Expected {expected_sum}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")