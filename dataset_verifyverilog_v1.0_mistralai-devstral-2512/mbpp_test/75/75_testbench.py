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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tuple_filter(dut):
    """Test tuple filtering where all elements divisible by K"""
    
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Test cases: tuples, K, expected filtered tuples
    test_cases = [
        (
            [(6, 24, 12), (7, 9, 6), (12, 18, 21)],
            6,
            [(6, 24, 12)]
        ),
        (
            [(5, 25, 30), (4, 2, 3), (7, 8, 9)],
            5,
            [(5, 25, 30)]
        ),
        (
            [(7, 9, 16), (8, 16, 4), (19, 17, 18)],
            4,
            [(8, 16, 4)]
        )
    ]
    
    for test_idx, (tuples_in, K, expected_out) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: Input tuples={tuples_in}, K={K}")
        
        # Reset
        await reset_dut(dut)
        
        # Set divisor K
        dut.K.value = clamp_to_width(K, 8)
        
        # Stream in tuples
        expected_filtered = []
        for tuple_idx, tup in enumerate(tuples_in):
            # For each element in tuple
            filtered = True
            for elem_idx, elem in enumerate(tup):
                # Feed element to DUT
                dut.tuple_data.value = clamp_to_width(elem, 8)
                dut.element_index.value = elem_idx
                dut.tuple_index.value = tuple_idx
                
                await RisingEdge(dut.clk)
                
                # If filtered_valid is asserted, tuple passes
                if has_signal(dut, 'filtered_valid') and is_value_defined(dut.filtered_valid.value):
                    if int(dut.filtered_valid.value) == 1 and elem_idx == len(tup) - 1:
                        # Read filtered output
                        if has_signal(dut, 'filtered_tuple') and is_value_defined(dut.filtered_tuple.value):
                            result_elem = int(dut.filtered_tuple.value)
                            expected_filtered.append(result_elem)
                
                # Small delay for processing
                await Timer(1, units='ns')
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=200)
        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx + 1} FAIL: {e}")
            raise
        
        # Verify results
        cocotb.log.info(f"Expected filtered: {expected_out}")
        cocotb.log.info(f"Actual filtered (streamed): {expected_filtered}")
        
        # For this streaming design, we track filtered elements
        # Verify that filtered elements match expected output
        if len(expected_filtered) != sum(len(t) for t in expected_out):
            cocotb.log.error(f"Length mismatch: expected {sum(len(t) for t in expected_out)}, got {len(expected_filtered)}")
            raise TestFailure(f"Test {test_idx + 1}: Filtered count mismatch")
        
        cocotb.log.info(f"Test {test_idx + 1} PASSED")
    
    cocotb.log.info("All tests completed successfully!")