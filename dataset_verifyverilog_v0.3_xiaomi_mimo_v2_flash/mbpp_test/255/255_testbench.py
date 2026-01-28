import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# CONFIGURATION
DATA_WIDTH = 2
ARRAY_SIZE = 3
MAX_N = 3
CLK_PERIOD_NS = 10

# MANDATORY HELPER FUNCTIONS
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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

# HELPER: Pack tuple values into single integer
def pack_tuple(values, element_bits=2):
    result = 0
    for i, val in enumerate(values):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

# HELPER: Unpack integer to list of indices
def unpack_tuple(packed, n, element_bits=2):
    result = []
    for i in range(n):
        val = (packed >> (i * element_bits)) & ((1 << element_bits) - 1)
        result.append(val)
    return result

# HELPER: Reset DUT
async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    if has_signal(dut, 'n'):
        dut.n.value = 0
    if has_signal(dut, 'symbols'):
        for i in range(3):
            dut.symbols[i].value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# HELPER: Wait for done signal
async def wait_for_done(dut, max_cycles=200):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# HELPER: Start computation
async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# HELPER: Write symbol array
async def write_symbols(dut, symbol_values):
    for i, val in enumerate(symbol_values):
        port_name = f'symbols_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        elif hasattr(dut, 'symbols'):
            try:
                dut.symbols[i].value = clamp_to_width(val, DATA_WIDTH)
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot write symbols[{i}]")
        else:
            raise TestFailure(f"Cannot find symbols port")

# MAIN TEST
@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_combinations_colors(dut):
    """Test combinations with replacement generator"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (symbol_values, n, expected_tuples_of_indices)
    # Symbol mapping: 0=Red, 1=Green, 2=Blue
    test_cases = [
        # Test 1: n=1
        ([0, 1, 2], 1, [[0], [1], [2]]),
        # Test 2: n=2
        ([0, 1, 2], 2, [[0,0], [0,1], [0,2], [1,1], [1,2], [2,2]]),
        # Test 3: n=3
        ([0, 1, 2], 3, [[0,0,0], [0,0,1], [0,0,2], [0,1,1], [0,1,2], [0,2,2], [1,1,1], [1,1,2], [1,2,2], [2,2,2]]),
    ]
    
    total_passed = 0
    total_failed = 0
    
    for case_idx, (symbol_vals, n_val, expected_indices) in enumerate(test_cases):
        test_name = f"Test {case_idx+1}: symbols={symbol_vals}, n={n_val}"
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"{test_name}")
        cocotb.log.info(f"{'='*60}")
        
        # Reset for new test
        await reset_dut(dut)
        
        # Write symbols
        await write_symbols(dut, symbol_vals)
        
        # Write n value
        if has_signal(dut, 'n'):
            dut.n.value = n_val
        else:
            cocotb.log.warning("Signal 'n' not found, assuming n=3")
            n_val = 3
        
        expected_tuples = expected_indices
        expected_count = len(expected_tuples)
        cocotb.log.info(f"Expected {expected_count} tuples")
        
        # Start computation
        await start_computation(dut)
        
        # Collect outputs
        collected_tuples = []
        
        # Wait for first valid output
        timeout = 0
        while not (is_value_defined(dut.tuple_valid.value) and int(dut.tuple_valid.value) == 1):
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 50:
                raise TestFailure("Timeout waiting for first tuple_valid")
        
        # Collect all tuples until done
        max_cycles = 200
        cycle_count = 0
        done_seen = False
        
        while cycle_count < max_cycles:
            # Read current cycle outputs
            if is_value_defined(dut.tuple_valid.value) and int(dut.tuple_valid.value) == 1:
                if is_value_defined(dut.tuple_out.value):
                    packed = int(dut.tuple_out.value)
                    unpacked = unpack_tuple(packed, n_val)
                    collected_tuples.append(unpacked)
                    cocotb.log.info(f"  Cycle {cycle_count}: packed=0x{packed:X}, unpacked={unpacked}")
            
            # Check for done
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_seen = True
                cocotb.log.info(f"  Cycle {cycle_count}: DONE asserted")
                break
            
            await RisingEdge(dut.clk)
            cycle_count += 1
        
        if not done_seen:
            cocotb.log.error(f"  FAIL: Done not asserted within {max_cycles} cycles")
            total_failed += 1
            continue
        
        # Verify results
        if len(collected_tuples) != expected_count:
            cocotb.log.error(f"  FAIL: Expected {expected_count} tuples, got {len(collected_tuples)}")
            cocotb.log.error(f"  Collected: {collected_tuples}")
            cocotb.log.error(f"  Expected: {expected_tuples}")
            total_failed += 1
            continue
        
        # Compare each tuple
        all_match = True
        for i, (actual, expected) in enumerate(zip(collected_tuples, expected_tuples)):
            if actual != expected:
                cocotb.log.error(f"  FAIL: Tuple {i}: expected {expected}, got {actual}")
                all_match = False
        
        if all_match:
            cocotb.log.info(f"  PASS: All {expected_count} tuples match expected")
            total_passed += 1
        else:
            total_failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"FINAL RESULTS: {total_passed}/{total_passed+total_failed} tests passed")
    cocotb.log.info(f"{'='*60}")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} test(s) failed")