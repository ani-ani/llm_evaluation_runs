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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    if has_signal(dut, 'chars_done'): dut.chars_done.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_string(dut, test_str):
    """Send 10 characters sequentially"""
    for i, ch in enumerate(test_str):
        # Send char
        dut.char_in.value = ord(ch)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        await RisingEdge(dut.clk)
    # Signal end of input
    dut.chars_done.value = 1
    await RisingEdge(dut.clk)
    dut.chars_done.value = 0
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_date_validator(dut):
    """Test the date validation module"""
    # Check if module has required signals
    if not all(has_signal(dut, s) for s in ['clk', 'rst_n', 'start', 'char_in', 'char_valid', 'chars_done', 'result', 'done']):
        raise TestFailure("Missing required signals")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ('03-11-2000', True, "Valid date"),
        ('15-01-2012', False, "Month > 12"),
        ('04-0-2040', False, "Day < 1"),
        ('06-04-2020', True, "Valid date"),
        ('01-01-2007', True, "Valid date"),
        ('03-32-2011', False, "Day > 31"),
        ('', False, "Empty string"),
        ('04-31-3000', False, "April has 30 days"),
        ('06-06-2005', True, "Valid date"),
        ('21-31-2000', False, "Month > 12"),
        ('04-12-2003', True, "Valid date"),
        ('04122003', False, "Missing hyphens"),
        ('20030412', False, "Wrong format"),
        ('2003-04', False, "Incomplete date"),
        ('2003-04-12', False, "Wrong format"),
        ('04-2003', False, "Incomplete date")
    ]
    
    passed = 0
    failed = 0
    
    for i, (date_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} ('{date_str}')")
        
        # Skip if string is empty (can't send chars)
        if not date_str:
            # For empty string, just check if we get error
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            # Wait a bit to see if we get error
            await Timer(200, units='ns')
            if has_signal(dut, 'error') and is_value_defined(dut.error.value) and int(dut.error.value) == 1:
                if expected == False:
                    passed += 1
                    continue
            # Also check result
            if is_value_defined(dut.result.value):
                result_val = int(dut.result.value)
                if result_val == (1 if expected else 0):
                    passed += 1
                else:
                    cocotb.log.error(f"FAIL: Expected {expected}, got {result_val}")
                    failed += 1
            else:
                cocotb.log.error("FAIL: Result undefined")
                failed += 1
            continue
        
        # Normal case
        try:
            # Send start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await RisingEdge(dut.clk)
            
            # Send the date string
            await send_string(dut, date_str)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=300)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_val = int(dut.result.value)
            expected_val = 1 if expected else 0
            
            if result_val != expected_val:
                raise TestFailure(f"Expected {expected_val}, got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Passed: {passed}/{passed+failed}")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

# Additional test for edge cases
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases with invalid characters"""
    if not all(has_signal(dut, s) for s in ['clk', 'rst_n', 'start', 'char_in', 'char_valid', 'chars_done', 'result', 'done']):
        return  # Skip if module doesn't exist
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    edge_cases = [
        ('ab-cd-efgh', False, "Non-numeric month"),
        ('00-12-2023', False, "Month = 0"),
        ('13-01-2023', False, "Month = 13"),
        ('02-30-2023', False, "Feb day > 29"),
        ('02-29-2020', True, "Feb 29 (simplified leap)"),
        ('00-00-0000', False, "Zero values"),
        ('01-31-2023', True, "Jan 31 valid"),
        ('04-31-2023', False, "Apr 31 invalid"),
    ]
    
    passed = 0
    failed = 0
    
    for date_str, expected, desc in edge_cases:
        cocotb.log.info(f"Edge test: {desc}")
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        await send_string(dut, date_str)
        
        try:
            await wait_for_done(dut, max_cycles=300)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_val = int(dut.result.value)
            expected_val = 1 if expected else 0
            
            if result_val != expected_val:
                raise TestFailure(f"Expected {expected_val}, got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Edge cases passed: {passed}/{passed+failed}")
    if failed > 0:
        raise TestFailure(f"{failed} edge case(s) failed")