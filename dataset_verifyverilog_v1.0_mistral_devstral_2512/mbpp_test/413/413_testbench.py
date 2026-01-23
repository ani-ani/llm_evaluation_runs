import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
NUM_RECORDS = 4
NUM_FIELDS = 3
MAX_NAME_LEN = 16
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
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_record(dut, record_idx, name, score1, score2):
    """Write a single record to the DUT."""
    # Write name (first 16 characters, padded with spaces if shorter)
    name_bytes = name.encode('ascii').ljust(MAX_NAME_LEN, b' ')
    
    for i in range(MAX_NAME_LEN):
        port_name = f"name_{record_idx}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = name_bytes[i]
        else:
            raise TestFailure(f"Signal {port_name} not found")
    
    # Write score1
    score1_port = f"score1_{record_idx}"
    if has_signal(dut, score1_port):
        getattr(dut, score1_port).value = clamp_to_width(score1, DATA_WIDTH)
    else:
        raise TestFailure(f"Signal {score1_port} not found")
    
    # Write score2
    score2_port = f"score2_{record_idx}"
    if has_signal(dut, score2_port):
        getattr(dut, score2_port).value = clamp_to_width(score2, DATA_WIDTH)
    else:
        raise TestFailure(f"Signal {score2_port} not found")

async def read_result(dut):
    """Read all result outputs."""
    results = []
    for i in range(NUM_RECORDS):
        port_name = f"result_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_extract_nth_element(dut):
    """Test extracting nth element from array of tuples (records)."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test data (matches Python test cases)
    # Records: (name, score1, score2)
    test_records = [
        ("Greyson Fulton", 98, 99),
        ("Brady Kent", 97, 96),
        ("Wyatt Knott", 91, 94),
        ("Beau Turnbull", 94, 98),
    ]
    
    # Test cases: (field_select, expected_values, description)
    test_cases = [
        (0, [ord('G'), ord('B'), ord('W'), ord('B')], "Extract first characters of names"),
        (1, [98, 97, 91, 94], "Extract score1 values"),
        (2, [99, 96, 94, 98], "Extract score2 values"),
    ]
    
    # Write all records to DUT
    for i, (name, score1, score2) in enumerate(test_records):
        await write_record(dut, i, name, score1, score2)
    
    passed = 0
    failed = 0
    
    for field_select, expected, description in test_cases:
        cocotb.log.info(f"\nTest: field_select={field_select} - {description}")
        
        try:
            # Set field select
            dut.field_select.value = field_select
            
            # Wait a bit for inputs to stabilize
            await Timer(10, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            results = await read_result(dut)
            
            # Validate
            cocotb.log.info(f"  Expected: {expected}")
            cocotb.log.info(f"  Got:      {results}")
            
            if results != expected:
                raise TestFailure(f"Mismatch: expected {expected}, got {results}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_case_zero_records(dut):
    """Test with fewer than 4 records (should handle gracefully)."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Write only 2 records
    test_records = [
        ("Test One", 10, 20),
        ("Test Two", 30, 40),
    ]
    
    # Write first two records
    for i, (name, score1, score2) in enumerate(test_records):
        await write_record(dut, i, name, score1, score2)
    
    # For remaining records, write zeros
    for i in range(2, NUM_RECORDS):
        await write_record(dut, i, "", 0, 0)
    
    # Test score2 extraction
    dut.field_select.value = 2
    await Timer(10, units='ns')
    await start_computation(dut)
    await wait_for_done(dut)
    
    results = await read_result(dut)
    expected = [20, 40, 0, 0]
    
    if results != expected:
        raise TestFailure(f"Edge case failed: expected {expected}, got {results}")
    
    cocotb.log.info(f"Edge case test PASS: {results}")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_values(dut):
    """Test with maximum values to check overflow handling."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Write max values
    test_records = [
        ("Max"*5, 255, 255),  # Max 8-bit values
        ("Min", 0, 0),
        ("Mid", 128, 128),
        ("Two", 127, 254),
    ]
    
    for i, (name, score1, score2) in enumerate(test_records):
        await write_record(dut, i, name, score1, score2)
    
    # Test score1 with max value
    dut.field_select.value = 1
    await Timer(10, units='ns')
    await start_computation(dut)
    await wait_for_done(dut)
    
    results = await read_result(dut)
    expected = [255, 0, 128, 127]
    
    if results != expected:
        raise TestFailure(f"Max value test failed: expected {expected}, got {results}")
    
    cocotb.log.info(f"Max value test PASS: {results}")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_name_extraction_details(dut):
    """Verify name extraction returns correct ASCII bytes."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Simple test with distinct first letters
    test_records = [
        ("Alice", 1, 2),
        ("Bob", 3, 4),
        ("Charlie", 5, 6),
        ("David", 7, 8),
    ]
    
    for i, (name, score1, score2) in enumerate(test_records):
        await write_record(dut, i, name, score1, score2)
    
    # Extract first characters
    dut.field_select.value = 0
    await Timer(10, units='ns')
    await start_computation(dut)
    await wait_for_done(dut)
    
    results = await read_result(dut)
    expected = [ord('A'), ord('B'), ord('C'), ord('D')]
    
    if results != expected:
        raise TestFailure(f"Name extraction failed: expected {expected}, got {results}")
    
    cocotb.log.info(f"Name extraction PASS: {[chr(r) for r in results]}")
