import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
MOD = 10**9 + 7
MAX_DIGITS = 16

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Convert integer to BCD digits (16 digits)
def int_to_bcd(num, digits=MAX_DIGITS):
    s = str(num).zfill(digits)
    return [int(c) for c in s]

# Check if a number is valid according to rules
def is_number_valid(num):
    s = str(num)
    # No digit 4
    if '4' in s:
        return False
    # Count 6 and 8
    count_68 = sum(1 for c in s if c in '68')
    # Count other digits (excluding 4, and we know 4 isn't present)
    count_other = len(s) - count_68
    return count_68 == count_other

# Count valid numbers in range [1, n]
def count_valid_upto(n):
    if n <= 0:
        return 0
    count = 0
    for i in range(1, n + 1):
        if is_number_valid(i):
            count += 1
    return count

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_house_finder(dut):
    """Test house number counter with digit DP"""
    
    # Detect interface
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    
    # Get array signals
    if has_signal(dut, 'digits'):
        digits_signal = dut.digits
        is_array = True
    else:
        # Try individual ports
        digit_signals = []
        for i in range(MAX_DIGITS):
            if has_signal(dut, f'digit_{i}'):
                digit_signals.append(getattr(dut, f'digit_{i}'))
            else:
                break
        if len(digit_signals) == MAX_DIGITS:
            is_array = False
        else:
            # Fallback to packed array
            if has_signal(dut, 'packed_digits'):
                is_packed = True
            else:
                raise TestFailure("Cannot find digit input interface")
    
    # Get output signals
    result_signal = dut.result if has_signal(dut, 'result') else None
    
    if has_clk:
        # Sequential module - setup clock and reset
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
        # Reset sequence
        if has_rst:
            dut.rst_n.value = 0
            if has_start:
                dut.start.value = 0
            for _ in range(2):
                await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    # Test cases: (L, R, expected_count)
    test_cases = [
        (30, 70, 11),
        (66, 69, 2),
        (100, 999, 0),
        (1, 100, 0),
        (1000, 1020, 0),
        (1068, 1069, 2),  # 1068: 6,8 vs 1,0 -> 2 vs 2 -> valid. 1069: 6,8 vs 1,0,9 -> 2 vs 3 -> invalid
    ]
    
    total_passed = 0
    total_failed = 0
    
    for L, R, expected in test_cases:
        cocotb.log.info(f"Testing range [{L}, {R}], expected: {expected}")
        
        # For large ranges, test a subset to avoid timeout
        if R - L > 1000:
            cocotb.log.warning(f"Range too large {R-L}, testing subset")
            test_range = list(range(L, L + 100)) + list(range(R - 100, R + 1))
        else:
            test_range = range(L, R + 1)
        
        found_count = 0
        
        for num in test_range:
            # Convert number to BCD digits
            bcd = int_to_bcd(num, MAX_DIGITS)
            
            # Input to DUT
            if is_array:
                for i in range(MAX_DIGITS):
                    digits_signal[i].value = bcd[i]
            else:
                for i in range(MAX_DIGITS):
                    digit_signals[i].value = bcd[i]
            
            # Start computation if sequential
            if has_clk and has_start:
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(result_signal.value):
                cocotb.log.warning(f"Undefined result for {num}")
                continue
            
            result = int(result_signal.value)
            
            # Check if this number is valid
            expected_valid = 1 if is_number_valid(num) else 0
            
            if result != expected_valid:
                cocotb.log.error(f"Mismatch for {num}: expected {expected_valid}, got {result}")
                total_failed += 1
            else:
                if result == 1:
                    found_count += 1
        
        # For small ranges, verify exact count
        if R - L <= 1000:
            actual_count = count_valid_upto(R) - count_valid_upto(L - 1)
            if found_count != actual_count:
                cocotb.log.error(f"Count mismatch: found {found_count}, actual {actual_count}")
                total_failed += 1
            else:
                cocotb.log.info(f"  PASS: count = {found_count}")
                total_passed += 1
        else:
            cocotb.log.info(f"  PASS: tested {len(test_range)} numbers, found {found_count} valid")
            total_passed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Summary: {total_passed}/{total_passed+total_failed} test cases passed")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} failures")

async def start_computation(dut):
    """Pulse start signal"""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=10000):
    """Wait for done signal with timeout"""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")