import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4      # Each digit is 4 bits (0-9)
ARRAY_SIZE = 4      # 4 digits: H1, H2, M1, M2
RESULT_WIDTH = 16   # Packed result
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def pack_digits(h1, h2, m1, m2):
    """Pack 4 digits into a 16-bit value."""
    return (h1 << 12) | (h2 << 8) | (m1 << 4) | m2

def unpack_digits(packed):
    """Extract 4 digits from 16-bit packed value."""
    h1 = (packed >> 12) & 0xF
    h2 = (packed >> 8) & 0xF
    m1 = (packed >> 4) & 0xF
    m2 = packed & 0xF
    return h1, h2, m1, m2

def time_to_string(h1, h2, m1, m2):
    """Convert digits to string format."""
    return f"{h1}{h2}:{m1}{m2}"

def count_digit_changes(str1, str2):
    """Count number of digit positions that differ."""
    return sum(1 for a, b in zip(str1, str2) if a != b)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'format'):
        dut.format.value = 0
    if has_signal(dut, 'time_in'):
        dut.time_in.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut, format_val, time_packed):
    """Pulse start signal and set inputs."""
    dut.format.value = format_val
    dut.time_in.value = time_packed
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST CASE DEFINITIONS
# ============================================================================

# Each test case: (format, input_time, expected_output, description)
TEST_CASES = [
    (24, "17:30", "17:30", "Valid 24-hour time"),
    (12, "17:30", "07:30", "17h invalid, change to 07"),
    (24, "99:99", "09:09", "All invalid, minimal changes"),
    (12, "05:54", "05:54", "Valid 12-hour time"),
    (12, "00:05", "01:05", "00h invalid in 12-hour"),
    (24, "23:80", "23:00", "Minute 80 invalid"),
    (24, "73:16", "03:16", "Hour 73 invalid"),
    (12, "03:77", "03:07", "Minute 77 invalid"),
    (12, "47:83", "07:03", "Both invalid"),
    (24, "23:88", "23:08", "Minute 88 invalid"),
    (24, "51:67", "01:07", "Both invalid"),
    (12, "10:33", "10:33", "Valid 12-hour time"),
    (12, "00:01", "01:01", "00h invalid"),
    (12, "07:74", "07:04", "Minute 74 invalid"),
    (12, "00:60", "01:00", "Both invalid"),
    (24, "08:32", "08:32", "Valid 24-hour time"),
    (24, "42:59", "02:59", "Hour 42 invalid"),
    (24, "19:87", "19:07", "Minute 87 invalid"),
    (24, "26:98", "06:08", "Both invalid"),
    (12, "12:91", "12:01", "Minute 91 invalid"),
    (12, "11:30", "11:30", "Valid 12-hour time"),
    (12, "90:32", "10:32", "Hour 90 invalid"),
    (12, "03:69", "03:09", "Minute 69 invalid"),
    (12, "33:83", "03:03", "Both invalid"),
    (24, "10:45", "10:45", "Valid 24-hour time"),
    (24, "65:12", "05:12", "Hour 65 invalid"),
    (24, "22:64", "22:04", "Minute 64 invalid"),
    (24, "48:91", "08:01", "Both invalid"),
    (12, "02:51", "02:51", "Valid 12-hour time"),
    (12, "40:11", "10:11", "Hour 40 invalid"),
    (12, "02:86", "02:06", "Minute 86 invalid"),
    (12, "99:96", "09:06", "Both invalid"),
    (24, "19:24", "19:24", "Valid 24-hour time"),
    (24, "55:49", "05:49", "Hour 55 invalid"),
    (24, "01:97", "01:07", "Minute 97 invalid"),
    (24, "39:68", "09:08", "Both invalid"),
    (24, "24:00", "04:00", "Hour 24 invalid"),
    (12, "91:00", "01:00", "Hour 91 invalid"),
    (24, "00:30", "00:30", "Valid 24-hour time"),
    (12, "13:20", "03:20", "Hour 13 invalid"),
    (12, "13:00", "03:00", "Hour 13 invalid"),
    (12, "42:35", "02:35", "Hour 42 invalid"),
    (12, "20:00", "10:00", "Hour 20 invalid"),
    (12, "21:00", "01:00", "Hour 21 invalid"),
    (24, "10:10", "10:10", "Valid 24-hour time"),
    (24, "30:40", "00:40", "Hour 30 invalid"),
    (24, "12:00", "12:00", "Valid 24-hour time"),
    (12, "10:60", "10:00", "Minute 60 invalid"),
    (24, "30:00", "00:00", "Hour 30 invalid"),
    (24, "34:00", "04:00", "Hour 34 invalid"),
    (12, "22:00", "02:00", "Hour 22 invalid"),
    (12, "20:20", "10:20", "Hour 20 invalid"),
]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_broken_clock_fix(dut):
    """Main test for BrokenClockFix module."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for format_val, input_time, expected_output, description in TEST_CASES:
        cocotb.log.info(f"Test: {description}")
        cocotb.log.info(f"  Input: {input_time} (format={format_val})")
        cocotb.log.info(f"  Expected: {expected_output}")
        
        try:
            # Parse input time string "HH:MM" to digits
            h1_in = int(input_time[0])
            h2_in = int(input_time[1])
            m1_in = int(input_time[3])
            m2_in = int(input_time[4])
            
            # Pack into 16-bit value
            input_packed = pack_digits(h1_in, h2_in, m1_in, m2_in)
            
            if is_sequential:
                # Start computation
                await start_computation(dut, format_val, input_packed)
                # Wait for done
                await wait_for_done(dut)
                # Read result
                result_packed = safe_int(dut.time_out.value)
            else:
                # Combinational - set inputs and wait
                if has_signal(dut, 'format'):
                    dut.format.value = format_val
                if has_signal(dut, 'time_in'):
                    dut.time_in.value = input_packed
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)  # Trigger computation
                    dut.start.value = 0
                await Timer(100, units='ns')  # Wait for propagation
                
                # Read result
                if has_signal(dut, 'time_out'):
                    result_packed = safe_int(dut.time_out.value)
                else:
                    raise TestFailure("No time_out signal found")
            
            # Unpack result
            h1_out, h2_out, m1_out, m2_out = unpack_digits(result_packed)
            result_str = time_to_string(h1_out, h2_out, m1_out, m2_out)
            
            # Verify result is valid for the format
            hour = h1_out * 10 + h2_out
            minute = m1_out * 10 + m2_out
            
            valid = False
            if format_val == 24:
                valid = (0 <= hour <= 23) and (0 <= minute <= 59)
            else:  # 12-hour
                valid = (1 <= hour <= 12) and (0 <= minute <= 59)
            
            if not valid:
                raise TestFailure(f"Result {result_str} is invalid for {format_val}-hour format")
            
            # Check minimal changes (optional but useful)
            input_str = input_time.replace(':', '')
            expected_str = expected_output.replace(':', '')
            actual_str = result_str.replace(':', '')
            
            # Count changes from input to actual
            changes_actual = count_digit_changes(input_str, actual_str)
            changes_expected = count_digit_changes(input_str, expected_str)
            
            if result_str != expected_output:
                # Check if we have same number of changes (if multiple optimal solutions)
                if changes_actual > changes_expected:
                    raise TestFailure(f"Result {result_str} has {changes_actual} changes, but {expected_output} has {changes_expected}")
                else:
                    cocotb.log.warning(f"  Result {result_str} differs from expected but has minimal changes ({changes_actual})")
            
            cocotb.log.info(f"  Result: {result_str} [OK]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
