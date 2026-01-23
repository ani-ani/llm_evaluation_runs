import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if hasattr(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_longest_sequence(dut):
    """Test longest nested sequence finder"""
    
    # Configuration
    CLK_PERIOD_NS = 10
    MAX_INTERVALS = 8
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: each is (num_intervals, [a_list], [b_list], expected_length, expected_sequence)
    test_cases = [
        # Example 1: 3 intervals
        (3, [3, 2, 1], [4, 5, 6], 3, [(1, 6), (2, 5), (3, 4)]),
        # Example 2: 5 intervals  
        (5, [10, 20, 30, 10, 30], [30, 40, 50, 60, 40], 3, [(10, 60), (30, 50), (30, 40)]),
        # Example 3: 6 intervals
        (6, [1, 1, 1, 1, 2, 3], [4, 5, 6, 7, 5, 5], 5, [(1, 7), (1, 6), (1, 5), (2, 5), (3, 5)]),
        # Additional test: duplicates
        (4, [1, 1, 2, 3], [5, 5, 4, 4], 3, [(1, 5), (2, 4), (3, 4)]),
        # Additional test: single interval
        (1, [5], [10], 1, [(5, 10)]),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (num_intervals, a_list, b_list, expected_len, expected_seq) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {num_intervals} intervals")
        
        # Pad inputs to MAX_INTERVALS
        a_input = a_list + [0] * (MAX_INTERVALS - len(a_list))
        b_input = b_list + [0] * (MAX_INTERVALS - len(b_list))
        
        # Write inputs individually
        for i in range(MAX_INTERVALS):
            dut.a_in[i].value = clamp_to_width(a_input[i], 8)
            dut.b_in[i].value = clamp_to_width(b_input[i], 8)
        
        # Write num_intervals
        dut.num_intervals.value = num_intervals
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read results
        if not is_value_defined(dut.length.value):
            cocotb.log.error(f"  FAIL: length is undefined")
            failed += 1
            continue
        
        actual_len = int(dut.length.value)
        
        # Read sequence
        actual_seq = []
        for i in range(8):
            if i < actual_len:
                a_val = int(dut.out_a[i].value)
                b_val = int(dut.out_b[i].value)
                actual_seq.append((a_val, b_val))
            else:
                # Check that unused outputs are zero
                if is_value_defined(dut.out_a[i].value) and int(dut.out_a[i].value) != 0:
                    cocotb.log.warning(f"  Warning: out_a[{i}] = {int(dut.out_a[i].value)}, expected 0")
                if is_value_defined(dut.out_b[i].value) and int(dut.out_b[i].value) != 0:
                    cocotb.log.warning(f"  Warning: out_b[{i}] = {int(dut.out_b[i].value)}, expected 0")
        
        # Verify length
        if actual_len != expected_len:
            cocotb.log.error(f"  FAIL: Length mismatch. Expected {expected_len}, got {actual_len}")
            failed += 1
            continue
        
        # Verify sequence
        if actual_seq != expected_seq:
            cocotb.log.error(f"  FAIL: Sequence mismatch.")
            cocotb.log.error(f"    Expected: {expected_seq}")
            cocotb.log.error(f"    Got:      {actual_seq}")
            failed += 1
            continue
        
        cocotb.log.info(f"  PASS: Length={actual_len}, Sequence={actual_seq}")
        passed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")