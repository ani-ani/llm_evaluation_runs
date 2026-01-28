import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v); return True
    except (ValueError, AttributeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, AttributeError):
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    if v < 0:
        # For negative values, represent as two's complement in the given width
        v = (1 << bits) + v
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def flatten_nested_tuple(test_tuple):
    """Convert nested tuple to flat array with markers.
    Marker: 255 = start of nested tuple, 254 = end of nested tuple.
    Negative values represent the tuple itself (for nested tuples).
    """
    result = []
    
    def recurse(t, depth):
        if isinstance(t, tuple):
            # Check if this tuple contains any even numbers
            has_even = False
            for item in t:
                if isinstance(item, tuple):
                    if recurse(item, depth + 1):
                        has_even = True
                elif isinstance(item, int) and item % 2 == 0:
                    has_even = True
            
            if has_even and depth > 0:
                result.append(255)  # Start marker
            
            for item in t:
                if isinstance(item, tuple):
                    recurse(item, depth + 1)
                elif isinstance(item, int) and item % 2 == 0:
                    result.append(item)
            
            if has_even and depth > 0:
                result.append(254)  # End marker
            
            return has_even
        else:
            # Leaf node
            return (t % 2 == 0)
    
    recurse(test_tuple, 0)
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_even_filter(dut):
    CLK_NS = 10
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from the problem
    test_cases = [
        ((4, 5, (7, 6, (2, 4)), 6, 8), "Test 1"),
        ((5, 6, (8, 7, (4, 8)), 7, 9), "Test 2"),
        ((5, 6, (9, 8, (4, 6)), 8, 10), "Test 3")
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_tuple, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running {desc}")
        
        try:
            # Flatten the tuple
            flattened = flatten_nested_tuple(test_tuple)
            cocotb.log.info(f"Flattened input: {flattened}")
            
            # Prepare input array (max 8 elements)
            input_data = flattened[:8]
            # Pad with 0 if needed
            while len(input_data) < 8:
                input_data.append(0)
            
            # Set input data
            for j in range(8):
                val = input_data[j]
                dut.data_in[j].value = clamp_to_width(val, 8)
            
            # Set depth (for nested tuples, depth is often 3)
            dut.depth.value = 3
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read output
            if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                raise TestFailure("Output valid flag not set")
            
            count = int(dut.count_out.value)
            output_data = []
            for j in range(8):
                val = int(dut.data_out[j].value)
                # Convert two's complement if negative
                if val >= 128:  # 0x80 or higher
                    val = val - 256
                output_data.append(val)
            
            # Expected output
            expected = flatten_nested_tuple(test_tuple)
            
            cocotb.log.info(f"Expected: {expected}, Got count={count}, Data={output_data[:count]}")
            
            if count != len(expected):
                raise TestFailure(f"Expected count {len(expected)}, got {count}")
            
            for j in range(count):
                if j >= len(output_data):
                    raise TestFailure(f"Output index {j} out of range")
                if output_data[j] != expected[j]:
                    raise TestFailure(f"Index {j}: expected {expected[j]}, got {output_data[j]}")
            
            passed += 1
            cocotb.log.info(f"{desc} PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"{desc} FAILED: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")