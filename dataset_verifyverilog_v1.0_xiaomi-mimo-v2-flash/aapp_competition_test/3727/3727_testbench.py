import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Constants
DATA_WIDTH = 16
MAX_ELEMENTS = 100000
CLK_NS = 10

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_beautiful_sequence(dut):
    """
    Test the beautiful sequence generator module.
    Tests various valid and invalid count combinations.
    """
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
        if is_seq:
            await RisingEdge(dut.clk)
        else:
            await Timer(1, units='ns')
    
    dut.rst_n.value = 1
    if is_seq:
        await RisingEdge(dut.clk)
    
    # Test cases: (a, b, c, d, expected_result)
    test_cases = [
        (2, 2, 2, 1, True),    # First example - YES
        (1, 2, 3, 4, False),   # Second example - NO
        (2, 2, 2, 3, False),   # Third example - NO
        (1, 0, 0, 0, True),    # Single 0
        (0, 1, 0, 0, True),    # Single 1
        (0, 0, 1, 0, True),    # Single 2
        (0, 0, 0, 1, True),    # Single 3
        (1, 1, 0, 0, True),    # 0-1 sequence
        (0, 1, 1, 0, True),    # 1-2 sequence
        (0, 0, 1, 1, True),    # 2-3 sequence
        (1, 1, 1, 1, True),    # All present
        (10, 10, 10, 10, True),# Larger counts
        (0, 1, 0, 1, False),   # 1 and 3 only - impossible
        (1, 0, 1, 0, False),   # 0 and 2 only - impossible
        (0, 0, 10, 0, True),   # Many 2s
        (10, 0, 0, 0, False),  # Many 0s only
        (0, 10, 0, 0, False),  # Many 1s only
        (0, 0, 0, 10, False),  # Many 3s only
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (a, b, c, d, expected_yes) in enumerate(test_cases):
        total = a + b + c + d
        cocotb.log.info(f"\nTest {test_idx+1}: a={a}, b={b}, c={c}, d={d}, total={total}, expected={'YES' if expected_yes else 'NO'}")
        
        try:
            # Set input counts
            if has_signal(dut, 'a'):
                dut.a.value = clamp_to_width(a, 16)
            if has_signal(dut, 'b'):
                dut.b.value = clamp_to_width(b, 16)
            if has_signal(dut, 'c'):
                dut.c.value = clamp_to_width(c, 16)
            if has_signal(dut, 'd'):
                dut.d.value = clamp_to_width(d, 16)
            
            # Start calculation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                await Timer(10, units='ns')
            
            # Collect sequence
            sequence = []
            start_time = cocotb.sim_time()
            max_cycles = 100050  # Maximum allowed cycles
            
            if is_seq:
                for cycle in range(max_cycles):
                    await RisingEdge(dut.clk)
                    
                    # Check for immediate impossible signal
                    if has_signal(dut, 'impossible') and is_value_defined(dut.impossible.value):
                        if int(dut.impossible.value) == 1:
                            if expected_yes:
                                raise TestFailure(f"Module reported impossible, but expected YES for counts ({a},{b},{c},{d})")
                            # Verify NO case
                            if has_signal(dut, 'result_valid'):
                                await RisingEdge(dut.clk)
                                # Ensure no valid result was produced
                                if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                                    raise TestFailure(f"Impossible flag set but result_valid also high")
                            passed += 1
                            break
                    
                    # Collect result if valid
                    if has_signal(dut, 'result_valid') and is_value_defined(dut.result_valid.value):
                        if int(dut.result_valid.value) == 1:
                            if is_value_defined(dut.result.value):
                                val = int(dut.result.value)
                                sequence.append(val)
                                cocotb.log.debug(f"Cycle {cycle}: Got value {val}")
                    
                    # Check done flag
                    if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                        if int(dut.done.value) == 1:
                            # Done received, sequence should be complete
                            break
                else:
                    raise TestFailure(f"Timeout after {max_cycles} cycles")
            else:
                # Combinational
                await Timer(100, units='ns')
            
            # Validate results for YES cases
            if expected_yes:
                if not sequence:
                    raise TestFailure(f"Expected YES but no sequence generated for ({a},{b},{c},{d})")
                
                # Check sequence length matches total
                if len(sequence) != total:
                    raise TestFailure(f"Sequence length {len(sequence)} != total counts {total}")
                
                # Check counts
                counts = {0: 0, 1: 0, 2: 0, 3: 0}
                for val in sequence:
                    if val not in [0, 1, 2, 3]:
                        raise TestFailure(f"Invalid value {val} in sequence")
                    counts[val] += 1
                
                if counts[0] != a or counts[1] != b or counts[2] != c or counts[3] != d:
                    raise TestFailure(f"Counts mismatch: got {counts}, expected (0:{a}, 1:{b}, 2:{c}, 3:{d})")
                
                # Check beautiful property: |diff| = 1
                for i in range(len(sequence) - 1):
                    diff = abs(sequence[i+1] - sequence[i])
                    if diff != 1:
                        raise TestFailure(f"Not beautiful: |{sequence[i+1]} - {sequence[i]}| = {diff} (should be 1)")
                
                cocotb.log.info(f"  Valid sequence generated: {sequence}")
                passed += 1
            else:
                # Expected NO - verify no valid sequence
                if sequence:
                    raise TestFailure(f"Module produced sequence but expected NO for ({a},{b},{c},{d})")
                passed += 1
        
        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx+1} FAILED: {e}")
            failed += 1
        
        # Reset for next test
        if is_seq:
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"\n=== All {passed}/{len(test_cases)} tests passed ===")
