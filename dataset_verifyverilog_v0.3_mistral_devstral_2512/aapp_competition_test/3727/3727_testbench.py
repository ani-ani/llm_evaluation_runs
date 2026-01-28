import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
MAX_LEN = 32
CLK_PERIOD_NS = 10

# Helper functions
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

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut, a, b, c, d):
    """Start computation with given counts."""
    dut.a.value = a
    dut.b.value = b
    dut.c.value = c
    dut.d.value = d
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=10000):
    """Wait for done signal."""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

def check_sequence(seq, a, b, c, d):
    """Check if sequence is beautiful and has correct counts."""
    # Check counts
    counts = [0, 0, 0, 0]
    for num in seq:
        if num < 0 or num > 3:
            return False, f"Invalid number {num}"
        counts[num] += 1
    
    if counts[0] != a or counts[1] != b or counts[2] != c or counts[3] != d:
        return False, f"Counts mismatch: got {counts}, expected [{a}, {b}, {c}, {d}]"
    
    # Check beautiful property
    for i in range(len(seq) - 1):
        if abs(seq[i] - seq[i+1]) != 1:
            return False, f"Not beautiful: |{seq[i]} - {seq[i+1]}| != 1"
    
    return True, "Valid"

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_beautiful_sequence(dut):
    """Test beautiful sequence generator."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (a, b, c, d, expected_possible)
    test_cases = [
        (2, 2, 2, 1, True),   # Example 1
        (1, 2, 3, 4, False),  # Example 2
        (2, 2, 2, 3, False),  # Example 3
        (1, 1, 0, 0, True),   # Simple case
        (0, 1, 1, 0, True),   # 1,2
        (0, 0, 1, 1, True),   # 2,3
        (1, 0, 0, 0, True),   # Single 0
        (0, 1, 0, 0, True),   # Single 1
        (0, 0, 1, 0, True),   # Single 2
        (0, 0, 0, 1, True),   # Single 3
        (1, 2, 1, 0, True),   # 1,0,1,2 or similar
        (0, 0, 0, 0, True),   # All zero (empty sequence)
    ]
    
    passed = 0
    failed = 0
    
    for a, b, c, d, expected in test_cases:
        dut._log.info(f"Testing a={a}, b={b}, c={c}, d={d}, expected={'YES' if expected else 'NO'}")
        
        # Start computation
        await start_computation(dut, a, b, c, d)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read results
        seq_len = safe_int(dut.seq_len.value)
        seq = []
        for i in range(seq_len):
            if is_value_defined(dut.seq_out[i].value):
                seq.append(int(dut.seq_out[i].value))
        
        # Check if expected matches
        if expected:
            # Should have found a sequence
            if seq_len == 0:
                dut._log.error(f"  FAIL: Expected sequence but got none")
                failed += 1
            else:
                valid, msg = check_sequence(seq, a, b, c, d)
                if valid:
                    dut._log.info(f"  PASS: Found valid sequence: {seq}")
                    passed += 1
                else:
                    dut._log.error(f"  FAIL: {msg}")
                    failed += 1
        else:
            # Should not find a sequence
            if seq_len == 0:
                dut._log.info(f"  PASS: Correctly reported impossible")
                passed += 1
            else:
                valid, msg = check_sequence(seq, a, b, c, d)
                if valid:
                    dut._log.error(f"  FAIL: Expected impossible but got valid sequence: {seq}")
                    failed += 1
                else:
                    dut._log.error(f"  FAIL: Got invalid sequence when expected NO: {msg}")
                    failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
