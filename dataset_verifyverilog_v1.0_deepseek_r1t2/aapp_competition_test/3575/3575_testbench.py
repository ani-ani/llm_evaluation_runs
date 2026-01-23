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
# CONFIGURATION
# ============================================================================

CLK_PERIOD_NS = 10
MAX_CYCLES = 100
EXPECTED_TIME_1 = 1 << 32  # 1.0 in Q32.32 format

# ============================================================================
# TEST FUNCTION
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_meeting_time(dut):
    """Test the meeting_time module with the two provided test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (n, edges, s, t, expected_valid, expected_time, description)
    # n: 0->1, 1->2, 2->3, 3->4
    # edges: bitmask for 0-1,0-2,0-3,1-2,1-3,2-3
    test_cases = [
        (
            2,                    # n=3 (value 2)
            0b001001,             # edges: 0-1 and 1-2
            0,                    # s=0
            2,                    # t=2
            1,                    # valid=1
            EXPECTED_TIME_1,      # expected time = 1.0
            "Case 1: n=3, edges 0-1,1-2, s=0, t=2"
        ),
        (
            3,                    # n=4 (value 3)
            0b100001,             # edges: 0-1 and 2-3
            0,                    # s=0
            3,                    # t=3
            0,                    # valid=0
            0,                    # expected_time (ignored)
            "Case 2: n=4, edges 0-1,2-3, s=0, t=3"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for n, edges, s, t, exp_valid, exp_time, desc in test_cases:
        cocotb.log.info(f"\nTest: {desc}")
        
        try:
            # Set inputs
            dut.n.value = n
            dut.edges.value = edges
            dut.s.value = s
            dut.t.value = t
            
            # Pulse start
            await RisingEdge(dut.clk)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done (should be high one cycle after start)
            done_seen = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_seen = True
                    break
            
            if not done_seen:
                raise TestFailure("Done signal not asserted within timeout")
            
            # Read outputs
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal is undefined")
            
            if not is_value_defined(dut.expected_time.value):
                raise TestFailure("Expected_time signal is undefined")
            
            actual_valid = int(dut.valid.value)
            actual_time = int(dut.expected_time.value)
            
            # Verify
            if actual_valid != exp_valid:
                raise TestFailure(f"Valid mismatch: expected {exp_valid}, got {actual_valid}")
            
            if exp_valid == 1 and actual_time != exp_time:
                raise TestFailure(f"Expected time mismatch: expected {exp_time}, got {actual_time}")
            
            cocotb.log.info(f"  PASS: valid={actual_valid}, time={actual_time if exp_valid else 'N/A'}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
