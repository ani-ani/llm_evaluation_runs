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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 4          # Language IDs and translator IDs are 4-bit
MAX_M = 4               # Maximum number of translators supported
CLK_PERIOD_NS = 10
MAX_WAIT_CYCLES = 20    # Timeout for waiting for valid/impossible

# ============================================================================
# TESTBENCH MAIN
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_language_pairing(dut):
    """Test the LanguagePairing module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, M, translators, expected_valid, expected_impossible, expected_pairs)
    # translators: list of (lang1, lang2)
    # expected_pairs: list of tuples [(tr1,tr2), (tr3,tr4)] or None
    test_cases = [
        # M=2, share a language
        (5, 2, [(0,1), (0,2)], True, False, [(0,1)]),
        # M=2, do not share
        (5, 2, [(0,1), (2,3)], False, True, None),
        # M=4, first pairing works
        (5, 4, [(0,1), (0,2), (1,3), (2,3)], True, False, [(0,1), (2,3)]),
        # M=4, second pairing works (first fails)
        (5, 4, [(0,1), (2,3), (0,2), (1,3)], True, False, [(0,2), (1,3)]),
        # M=4, third pairing works (first and second fail)
        (5, 4, [(0,1), (2,3), (0,2), (1,4)], True, False, [(0,3), (1,2)]),
        # M=1 (odd)
        (5, 1, [(0,1)], False, True, None),
        # M=3 (odd)
        (5, 3, [(0,1), (0,2), (1,2)], False, True, None),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, M, translators, exp_valid, exp_impossible, exp_pairs) in enumerate(test_cases):
        dut._log.info(f"\nTest case {i+1}: N={N}, M={M}")
        
        # Set N and M
        dut.N.value = N
        dut.M.value = M
        
        # Set translator inputs
        # We have up to 4 translators; set only the first M
        for tr_id in range(MAX_M):
            if tr_id < M:
                lang1, lang2 = translators[tr_id]
                setattr(dut, f'lang1_{tr_id}', lang1)
                setattr(dut, f'lang2_{tr_id}', lang2)
            else:
                # Unused translators: set to 0
                setattr(dut, f'lang1_{tr_id}', 0)
                setattr(dut, f'lang2_{tr_id}', 0)
        
        # Wait one cycle to ensure inputs are stable
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for valid or impossible to be asserted
        timeout = 0
        while timeout < MAX_WAIT_CYCLES:
            await RisingEdge(dut.clk)
            if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                break
            if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
                break
            timeout += 1
        else:
            dut._log.error(f"  Timeout waiting for valid/impossible")
            failed += 1
            continue
        
        # Read outputs
        valid = int(dut.valid.value)
        impossible = int(dut.impossible.value)
        
        dut._log.info(f"  valid={valid}, impossible={impossible}")
        
        # Check expected validity
        if valid != exp_valid or impossible != exp_impossible:
            dut._log.error(f"  Expected valid={exp_valid}, impossible={exp_impossible}")
            failed += 1
            continue
        
        # If valid, check the pairs
        if valid and exp_pairs is not None:
            tr1_1 = int(dut.pair1_tr1.value)
            tr1_2 = int(dut.pair1_tr2.value)
            tr2_1 = int(dut.pair2_tr1.value)
            tr2_2 = int(dut.pair2_tr2.value)
            
            # For M=2, we only care about the first pair
            if M == 2:
                output_pairs = [(tr1_1, tr1_2)]
            else:
                output_pairs = [(tr1_1, tr1_2), (tr2_1, tr2_2)]
            
            dut._log.info(f"  Output pairs: {output_pairs}")
            
            # Check that the output pairs are exactly the expected ones (order may differ within pair)
            # We'll compare as sets of sorted tuples
            expected_set = {tuple(sorted(p)) for p in exp_pairs}
            output_set = {tuple(sorted(p)) for p in output_pairs}
            
            if expected_set == output_set:
                dut._log.info(f"  PASS")
                passed += 1
            else:
                dut._log.error(f"  Expected pairs {exp_pairs}, got {output_pairs}")
                failed += 1
        elif valid and exp_pairs is None:
            # Should not happen in our test cases
            dut._log.error(f"  Unexpected valid with no expected pairs")
            failed += 1
        else:
            # impossible case or no pairs to check
            dut._log.info(f"  PASS")
            passed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
