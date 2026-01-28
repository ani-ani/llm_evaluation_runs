import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 16
MAX_CYCLES = 50
CLK_NS = 10

# Helper functions

def is_value_defined(v):
    """Check if a signal value is defined (not 'X' or 'Z')"""
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    """Safely convert to int, return default on error"""
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    """Clamp value to fit in given bit width (unsigned)"""
    max_val = (1 << bits) - 1
    return max(0, min(v, max_val))

def has_signal(dut, name):
    """Check if a signal exists on the DUT"""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    """Perform synchronous active-low reset"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles - done not asserted")

async def set_number(dut, number):
    """Set the input number with proper width clamping"""
    clamped = clamp_to_width(number, DATA_WIDTH)
    dut.number.value = clamped
    await Timer(10, units='ns')

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_armstrong_number(dut):
    """Test the Armstrong number checker"""
    
    # Check if DUT has required signals
    required_inputs = ['clk', 'rst_n', 'start', 'number']
    required_outputs = ['result', 'done']
    
    for sig in required_inputs + required_outputs:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Initial reset
    await reset_dut(dut)
    
    # Test cases: (input, expected_result, description)
    test_cases = [
        (153, 1, "Armstrong: 1^3 + 5^3 + 3^3 = 153"),
        (259, 0, "Non-Armstrong: 2^3 + 5^3 + 9^3 = 862 ≠ 259"),
        (4458, 0, "Non-Armstrong: 4^4 + 4^4 + 5^4 + 8^4 = 5233 ≠ 4458"),
        (1, 1, "Single digit Armstrong: 1^1 = 1"),
        (9, 1, "Single digit Armstrong: 9^1 = 9"),
        (0, 1, "Zero is Armstrong: 0^1 = 0"),
        (153, 1, "Armstrong: 153 repeated"),
        (1634, 1, "4-digit Armstrong: 1^4 + 6^4 + 3^4 + 4^4 = 1634"),
        (9474, 1, "4-digit Armstrong: 9^4 + 4^4 + 7^4 + 4^4 = 9474"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Prepare input (clamp to 16-bit)
            test_input = clamp_to_width(inp, DATA_WIDTH)
            
            # Wait for previous cycle to complete
            await RisingEdge(dut.clk)
            
            # Set input
            await set_number(dut, test_input)
            
            # Assert start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result (valid when done is high)
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X or Z)")
            
            result = int(dut.result.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result} for input {test_input}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {test_input} -> {result}")
            
            # Verify done is single cycle
            await RisingEdge(dut.clk)
            if int(dut.done.value) == 1:
                raise TestFailure("Done signal not single-cycle (still high after 1 cycle)")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} - {e}")
            failed += 1
    
    # Summary
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_timing_constraints(dut):
    """Test that computation completes within 40 cycles"""
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test with a 4-digit number (max cycles test)
    test_input = 1634  # 4-digit Armstrong
    
    await set_number(dut, test_input)
    
    # Measure cycles from start pulse
    dut.start.value = 1
    start_cycle = cocotb.sim_time(units='ns') / CLK_NS
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles_passed = 0
    for _ in range(50):  # Max 50 cycles
        await RisingEdge(dut.clk)
        cycles_passed += 1
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            end_cycle = cocotb.sim_time(units='ns') / CLK_NS
            total_cycles = int(end_cycle - start_cycle)
            
            if total_cycles > 40:
                raise TestFailure(f"Computation took {total_cycles} cycles, exceeds 40 cycle limit")
            
            cocotb.log.info(f"Timing: {test_input} completed in {total_cycles} cycles (limit: 40)")
            return True
    
    raise TestFailure(f"Did not complete within 50 cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_single_digit_numbers(dut):
    """Test all single-digit numbers (all should be Armstrong)"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    for digit in range(10):
        await set_number(dut, digit)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        
        # All single digits are Armstrong numbers
        if result != 1:
            raise TestFailure(f"Single digit {digit} should be Armstrong (result=1), got {result}")
        
        cocotb.log.info(f"Single digit {digit}: Armstrong = {result} (expected 1)")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_zero_input(dut):
    """Test zero input (edge case)"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Zero should be considered Armstrong
    await set_number(dut, 0)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    
    # 0^1 = 0, so 0 is Armstrong
    if result != 1:
        raise TestFailure(f"Zero should be Armstrong (0^1 = 0), got result={result}")
    
    cocotb.log.info(f"Zero: Armstrong = {result} (expected 1)")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_non_armstrong_patterns(dut):
    """Test various non-Armstrong numbers"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    non_armstrong_tests = [
        (123, "1^3 + 2^3 + 3^3 = 1+8+27=36 ≠ 123"),
        (456, "4^3 + 5^3 + 6^3 = 64+125+216=405 ≠ 456"),
        (789, "7^3 + 8^3 + 9^3 = 343+512+729=1584 ≠ 789"),
        (100, "1^3 + 0^3 + 0^3 = 1 ≠ 100"),
        (1234, "4-digit non-Armstrong"),
    ]
    
    for (inp, desc) in non_armstrong_tests:
        await set_number(dut, inp)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        
        if result != 0:
            raise TestFailure(f"Non-Armstrong {inp} should return 0, got {result} - {desc}")
        
        cocotb.log.info(f"Non-Armstrong {inp}: {result} (expected 0) - {desc}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_consecutive_computations(dut):
    """Test multiple consecutive computations"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_sequence = [
        (153, 1),
        (123, 0),
        (370, 1),
        (999, 0),
        (1, 1),
    ]
    
    for (inp, exp) in test_sequence:
        await set_number(dut, inp)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        
        if result != exp:
            raise TestFailure(f"Sequence {inp}: Expected {exp}, got {result}")
        
        cocotb.log.info(f"Sequence {inp}: {result} (expected {exp})")
        
        # Ensure we're back in IDLE for next computation
        await RisingEdge(dut.clk)
        if int(dut.done.value) == 1:
            raise TestFailure("Done not deasserted after completion")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_16bit_number(dut):
    """Test maximum 16-bit unsigned number (65535)"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    max_input = 65535
    
    await set_number(dut, max_input)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value)
    
    # 65535 is not Armstrong (6^5 + 5^5 + 5^5 + 3^5 + 5^5 = 7776+3125+3125+243+3125=14394)
    if result != 0:
        raise TestFailure(f"65535 should not be Armstrong, got result={result}")
    
    cocotb.log.info(f"Max 16-bit (65535): Armstrong = {result} (expected 0)")