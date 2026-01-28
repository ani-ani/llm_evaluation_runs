import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_items(dut, items):
    """Load items sequentially via item streams"""
    for size, value in items:
        # Clamp to bit widths
        size_val = clamp_to_width(size, 8)
        value_val = clamp_to_width(value, 16)
        
        dut.item_size.value = size_val
        dut.item_value.value = value_val
        dut.item_valid.value = 1
        
        await RisingEdge(dut.clk)
        dut.item_valid.value = 0
        # Wait for internal processing (allow 64 cycles per item)
        for _ in range(64):
            await RisingEdge(dut.clk)
    
    # Signal item stream done
    dut.item_done.value = 1
    await RisingEdge(dut.clk)
    dut.item_done.value = 0

async def read_dp_output(dut):
    """Read and unpack dp_out signal"""
    if not has_signal(dut, 'dp_out'):
        raise TestFailure("dp_out signal not found")
    
    dp_val = int(dut.dp_out.value)
    dp = []
    for i in range(1, 65):  # Capacities 1 to 64
        # Extract 16-bit chunks (dp[1] is bits [15:0], dp[2] is [31:16], etc.)
        chunk = (dp_val >> ((i-1) * 16)) & 0xFFFF
        dp.append(chunk)
    return dp

async def compute_knapsack_python(items, max_cap=64):
    """Reference 0/1 knapsack DP in Python"""
    # Initialize DP array: dp[cap] = max value for capacity cap
    dp = [0] * (max_cap + 1)  # Index 0..max_cap
    
    for size, value in items:
        if size > max_cap:
            continue
        # Iterate backwards to avoid using item twice
        for cap in range(max_cap, size - 1, -1):
            if dp[cap - size] + value > dp[cap]:
                dp[cap] = dp[cap - size] + value
    
    # Return values for capacities 1..max_cap
    return dp[1:]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_knapsack_multi_capacity(dut):
    """Test the knapsack module with multiple items and capacities"""
    
    # Setup clock and reset
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (items, expected_dp_for_1_64)
    test_cases = [
        # Example 1: 4 items, max cap 9
        (
            [(2, 8), (1, 1), (3, 4), (5, 100)],
            [1, 8, 9, 9, 100, 101, 108, 109, 109] + [109] * 55  # Pad to 64
        ),
        # Example 2: 5 items, max cap 7
        (
            [(2, 2), (3, 8), (2, 7), (2, 4), (3, 8)],
            [0, 7, 8, 11, 15, 16, 19] + [19] * 57  # Pad to 64
        ),
        # Example 3: 2 items too large
        (
            [(300, 1), (300, 2)],
            [0] * 64  # All zeros, sizes > 64
        ),
        # Empty knapsack
        (
            [],
            [0] * 64
        ),
        # Single item
        (
            [(10, 5000)],
            [0] * 9 + [5000] + [5000] * 54
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (items, expected_full) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: {len(items)} items")
        
        try:
            # Reset before each test
            if has_signal(dut, 'rst_n'):
                await reset_dut(dut)
            
            # Trigger start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Load items
            await load_items(dut, items)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=4500)  # 64 items * 64 cycles + overhead
            
            # Read output
            result = await read_dp_output(dut)
            
            # Verify (compare first len(expected) entries)
            expected = expected_full[:64]
            if len(expected) != 64:
                raise TestFailure(f"Expected length {len(expected)} != 64")
            
            # Check each capacity
            for cap in range(1, 65):
                actual = result[cap-1]
                exp_val = expected[cap-1]
                if actual != exp_val:
                    raise TestFailure(
                        f"Capacity {cap}: Expected {exp_val}, got {actual}. "
                        f"Items: {items}, Full result: {result}"
                    )
            
            passed += 1
            cocotb.log.info(f"Test {i+1} PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
