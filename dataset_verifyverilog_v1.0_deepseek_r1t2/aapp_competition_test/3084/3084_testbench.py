import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

# ============================================================================
# TIME CONVERSION HELPERS
# ============================================================================

def time_to_digits(time_str):
    """Convert 'hh:mm' to (hours, minutes) as integers."""
    parts = time_str.split(':')
    return int(parts[0]), int(parts[1])

def digits_to_time(hours, minutes):
    """Convert hours and minutes to 'hh:mm' string."""
    return f"{hours:02d}:{minutes:02d}"

def time_to_binary(hours, minutes):
    """Convert time to binary representation for HDL."""
    return (hours << 8) | minutes

# ============================================================================
# MAIN TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_clock_setting(dut):
    """Test the clock setting module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.orig_time_h.value = 0
    dut.orig_time_m.value = 0
    dut.target_time_h.value = 0
    dut.target_time_m.value = 0
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("00:00", "01:01"),
        ("00:08", "00:00"),
        ("09:09", "20:10")
    ]
    
    expected_sequences = [
        ["00:00", "01:00", "01:01"],
        ["00:08", "00:09", "00:00"],
        ["09:09", "09:00", "09:10", "00:10", "10:10", "20:10"]
    ]
    
    for test_idx, (orig_str, target_str) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {orig_str} -> {target_str}")
        
        orig_h, orig_m = time_to_digits(orig_str)
        target_h, target_m = time_to_digits(target_str)
        
        # Set inputs
        dut.orig_time_h.value = orig_h
        dut.orig_time_m.value = orig_m
        dut.target_time_h.value = target_h
        dut.target_time_m.value = target_m
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect sequence
        sequence = []
        
        # Wait for first valid output (original time)
        timeout = 0
        while not is_value_defined(dut.valid.value) or int(dut.valid.value) == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 100:
                raise TestFailure(f"Test {test_idx+1}: Timeout waiting for valid output")
        
        # Read original time
        if is_value_defined(dut.current_time_h.value) and is_value_defined(dut.current_time_m.value):
            h = int(dut.current_time_h.value)
            m = int(dut.current_time_m.value)
            sequence.append(digits_to_time(h, m))
            cocotb.log.info(f"  Step {len(sequence)}: {sequence[-1]}")
        
        # Continue reading until done
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                if is_value_defined(dut.current_time_h.value) and is_value_defined(dut.current_time_m.value):
                    h = int(dut.current_time_h.value)
                    m = int(dut.current_time_m.value)
                    time_str = digits_to_time(h, m)
                    if time_str != sequence[-1]:  # Only add if different
                        sequence.append(time_str)
                        cocotb.log.info(f"  Step {len(sequence)}: {sequence[-1]}")
        
        # Verify sequence
        expected = expected_sequences[test_idx]
        if sequence != expected:
            raise TestFailure(f"Test {test_idx+1}: Expected {expected}, got {sequence}")
        
        cocotb.log.info(f"  PASS: Sequence correct ({len(sequence)} steps)")
    
    cocotb.log.info("\n" + "="*50)
    cocotb.log.info("All tests passed!")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_clock_setting_edge_cases(dut):
    """Test edge cases for clock setting."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: same time
    dut.orig_time_h.value = 12
    dut.orig_time_m.value = 30
    dut.target_time_h.value = 12
    dut.target_time_m.value = 30
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Should get one output (original time) and then done
    timeout = 0
    outputs = []
    while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            if is_value_defined(dut.current_time_h.value) and is_value_defined(dut.current_time_m.value):
                h = int(dut.current_time_h.value)
                m = int(dut.current_time_m.value)
                outputs.append(digits_to_time(h, m))
        timeout += 1
        if timeout > 100:
            break
    
    if len(outputs) != 1 or outputs[0] != "12:30":
        raise TestFailure(f"Same time test failed: got {outputs}")
    
    cocotb.log.info("Edge cases passed!")
