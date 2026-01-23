import cocotb
from cocotb.triggers import Timer
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 16
N = 4
ADDR_WIDTH = 2

def compute_answer(houses_x, houses_y, a, b):
    """Compute minimal side length for a range [a,b] inclusive."""
    # Find extremes
    min_x = houses_x[a]
    max_x = houses_x[a]
    min_y = houses_y[a]
    max_y = houses_y[a]
    idx_min_x = a
    idx_max_x = a
    idx_min_y = a
    idx_max_y = a

    for i in range(a+1, b+1):
        if houses_x[i] < min_x:
            min_x = houses_x[i]
            idx_min_x = i
        if houses_x[i] > max_x:
            max_x = houses_x[i]
            idx_max_x = i
        if houses_y[i] < min_y:
            min_y = houses_y[i]
            idx_min_y = i
        if houses_y[i] > max_y:
            max_y = houses_y[i]
            idx_max_y = i

    L0 = max(max_x - min_x, max_y - min_y)
    result = L0

    # Candidates
    candidates = {idx_min_x, idx_max_x, idx_min_y, idx_max_y}

    for c in candidates:
        first = True
        for i in range(a, b+1):
            if i == c:
                continue
            if first:
                min_x_c = houses_x[i]
                max_x_c = houses_x[i]
                min_y_c = houses_y[i]
                max_y_c = houses_y[i]
                first = False
            else:
                if houses_x[i] < min_x_c:
                    min_x_c = houses_x[i]
                if houses_x[i] > max_x_c:
                    max_x_c = houses_x[i]
                if houses_y[i] < min_y_c:
                    min_y_c = houses_y[i]
                if houses_y[i] > max_y_c:
                    max_y_c = houses_y[i]
        if not first:
            L_c = max(max_x_c - min_x_c, max_y_c - min_y_c)
            if L_c < result:
                result = L_c

    return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_house_zone(dut):
    """Test HouseZone module with fixed data."""

    # Define test houses (addresses 0..3)
    houses_x = [1, 0, 1000, 5]
    houses_y = [0, 1, 1, 5]

    # Define queries: (a, b) inclusive indices
    queries = [
        (0, 2),  # houses 0,1,2 -> should give 1
        (1, 3),  # houses 1,2,3 -> compute expected
    ]

    # Write houses to DUT (signed assignment)
    for i in range(N):
        dut.house_x[i].value = from_signed(houses_x[i], DATA_WIDTH)
        dut.house_y[i].value = from_signed(houses_y[i], DATA_WIDTH)

    # Wait a bit for signals to settle
    await Timer(10, units='ns')

    # Process each query
    for idx, (a, b) in enumerate(queries):
        # Set query inputs (unsigned)
        dut.query_a.value = a
        dut.query_b.value = b

        # Wait for combinational propagation
        await Timer(10, units='ns')

        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Query {idx}: result is undefined (X/Z)")

        raw_result = int(dut.result.value)
        actual = to_signed(raw_result, DATA_WIDTH)

        # Compute expected
        expected = compute_answer(houses_x, houses_y, a, b)

        if actual != expected:
            raise TestFailure(f"Query {idx}: expected {expected}, got {actual}")

        dut._log.info(f"Query {idx} [{a},{b}] = {actual} (OK)")

    dut._log.info("All tests passed.")