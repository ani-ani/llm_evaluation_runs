import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
K_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try individual ports first (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            # Try 2D array
            try:
                arr = getattr(dut, array_name)
                arr[i].value = clamp_to_width(val, element_width)
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot find array port: {port_name} or {array_name}[{i}]")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    # Try individual ports first
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            # Try 2D array
            try:
                arr = getattr(dut, array_name)
                val = arr[i].value
                if is_value_defined(val):
                    results.append(int(val))
                else:
                    results.append(None)
            except (AttributeError, TypeError):
                results.append(None)
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS (included for template compliance)
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        
        for _ in range(cycles):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
        
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    if not has_signal(dut, 'done'):
        # Combinational - just wait for propagation
        await Timer(100, units='ns')
        return True
    
    for cycle in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    if has_signal(dut, 'start'):
        dut.start.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        dut.start.value = 0

# ============================================================================
# GRUNDY REFERENCE FUNCTION
# ============================================================================

def grundy_reference(pile, k):
    """Compute grundy number for a single pile (reference for testing)."""
    pile = clamp_to_width(pile, DATA_WIDTH)
    k = clamp_to_width(k, K_WIDTH)
    
    if k % 2 == 0:  # k even
        if pile < 3:
            return pile
        else:
            return (pile & 1) ^ 1
    else:  # k odd
        if pile < 4:
            return pile & 1
        else:
            if pile & 1:  # odd
                return 0
            else:
                # Compute trailing zeros
                d = 0
                while (pile & (1 << d)) == 0:
                    d += 1
                    if d >= DATA_WIDTH:
                        break
                three_shl_d = 3 << d
                cond = (pile == three_shl_d) ^ (d & 1)
                return 1 if cond else 2

def compute_expected_winner(piles, k):
    """Compute expected winner for given piles and k."""
    xor_sum = 0
    for pile in piles:
        g = grundy_reference(pile, k)
        xor_sum ^= g
    return 1 if xor_sum != 0 else 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_lieges_of_legendre(dut):
    """Main test for Lieges of Legendre module."""
    
    # Detect module interface
    is_sequential = has_signal(dut, 'clk')
    is_combinational = not is_sequential
    
    dut._log.info(f"Module type: {'Sequential' if is_sequential else 'Combinational'}")
    
    # Start clock if sequential
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    # Define test cases: (piles, k, expected_winner, description)
    test_cases = [
        # Original examples
        ([3, 4], 1, 1, "Example 1: Kevin"),
        ([3], 2, 0, "Example 2: Nicky"),
        
        # Edge cases
        ([0]*8, 1, 0, "All zeros"),
        ([255]*8, 255, 1, "Max values, k odd"),
        ([1]*8, 2, 1, "All ones, k even"),
        ([2]*8, 2, 0, "All twos, k even"),
        ([3]*8, 1, 0, "All threes, k odd"),
        
        # Pattern tests
        ([4, 6, 8, 10, 12, 14, 16, 18], 1, 1, "Even numbers, k odd"),
        ([5, 7, 9, 11, 13, 15, 17, 19], 2, 0, "Odd numbers, k even"),
        ([2, 4, 8, 16, 32, 64, 128, 255], 1, 1, "Powers of 2, k odd"),
        
        # Specific grundy values
        ([4], 1, 1, "Value 4 (grundy=2)"),
        ([6], 1, 1, "Value 6 (grundy=2)"),
        ([8], 1, 1, "Value 8 (grundy=1)"),
        ([12], 1, 1, "Value 12 (grundy=1)"),
        ([16], 1, 1, "Value 16 (grundy=2)"),
        ([24], 1, 1, "Value 24 (grundy=1)"),
        ([32], 1, 1, "Value 32 (grundy=2)"),
        ([48], 1, 1, "Value 48 (grundy=1)"),
        ([128], 1, 1, "Value 128 (3<<7=384, cond=True, grundy=1)"),
        ([192], 1, 1, "Value 192 (3<<6=192, cond=True, grundy=1)"),
        
        # Mixed cases
        ([1, 2, 3, 4, 5, 6, 7, 8], 1, 1, "Sequential 1-8"),
        ([2, 3, 5, 7, 11, 13, 17, 19], 2, 1, "Primes"),
        
        # Single pile edge cases
        ([1], 1, 1, "Single 1"),
        ([2], 1, 0, "Single 2"),
        ([3], 1, 1, "Single 3"),
        ([4], 1, 1, "Single 4"),
    ]
    
    # Pad test cases to 8 piles
    full_test_cases = []
    for piles, k, expected, desc in test_cases:
        padded = (piles + [0] * 8)[:8]
        full_test_cases.append((padded, k, expected, desc))
    
    passed = 0
    failed = 0
    
    for i, (piles, k, expected, description) in enumerate(full_test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        dut._log.info(f"  Piles: {piles}, k: {k}")
        
        try:
            # Write inputs
            for idx, val in enumerate(piles):
                port_name = f"arr_{idx}"
                if not has_signal(dut, port_name):
                    raise TestFailure(f"Missing port: {port_name}")
                getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
            
            dut.k.value = clamp_to_width(k, K_WIDTH)
            
            # Wait for propagation
            if is_sequential:
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                await Timer(10, units='ns')
            
            # Read output
            if not has_signal(dut, 'winner'):
                raise TestFailure("Missing output: winner")
            
            winner_val = dut.winner.value
            if not is_value_defined(winner_val):
                raise TestFailure("Winner output is undefined")
            
            winner = int(winner_val)
            
            # Verify
            if winner != expected:
                got = "Kevin" if winner else "Nicky"
                exp = "Kevin" if expected else "Nicky"
                raise TestFailure(f"Expected {exp}, got {got}")
            
            dut._log.info(f"  PASS: {dut.winner.value} == {expected}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*60}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")