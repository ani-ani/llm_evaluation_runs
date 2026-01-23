import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Helper functions from the template
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Convert a 2D list to a flattened list for easier assignment
flatten = lambda l: [item for sublist in l for item in sublist]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_two_card_checker(dut):
    """Test the BingoTwoCardChecker with sample input."""
    
    # Define the two cards from the sample input
    card1 = [
        [3, 29, 45, 56, 68],
        [1, 19, 43, 50, 72],
        [11, 25, 40, 49, 61],
        [9, 23, 31, 58, 63],
        [4, 27, 42, 54, 71]
    ]
    card2 = [
        [14, 23, 39, 59, 63],
        [8, 17, 35, 55, 61],
        [15, 26, 42, 53, 71],
        [10, 25, 31, 57, 64],
        [6, 20, 44, 52, 68]
    ]

    # Load card1 into the DUT
    for i in range(5):
        for j in range(5):
            # Use the hierarchical access to set each element
            # The module expects card1[i][j]
            if has_signal(dut, f'card1_{i}_{j}'):
                # Individual port naming (card1_0_0, card1_0_1, ...)
                getattr(dut, f'card1_{i}_{j}').value = clamp_to_width(card1[i][j], 12)
            else:
                # Try 2D array indexing
                try:
                    dut.card1[i][j].value = clamp_to_width(card1[i][j], 12)
                except (AttributeError, TypeError):
                    raise TestFailure(f"Cannot find port for card1[{i}][{j}]")

    # Load card2 into the DUT
    for i in range(5):
        for j in range(5):
            if has_signal(dut, f'card2_{i}_{j}'):
                getattr(dut, f'card2_{i}_{j}').value = clamp_to_width(card2[i][j], 12)
            else:
                try:
                    dut.card2[i][j].value = clamp_to_width(card2[i][j], 12)
                except (AttributeError, TypeError):
                    raise TestFailure(f"Cannot find port for card2[{i}][{j}]")

    # Wait for combinational logic to settle
    await Timer(100, units='ns')

    # Read results
    if not is_value_defined(dut.tie_found.value):
        raise TestFailure("tie_found is undefined (X/Z)")
    
    tie_found = int(dut.tie_found.value)
    
    # The sample input should result in a tie
    if tie_found != 1:
        raise TestFailure(f"Expected tie_found=1, got {tie_found}")

    # Check the rows that tie
    if is_value_defined(dut.tie_row1.value):
        row1 = int(dut.tie_row1.value)
    else:
        raise TestFailure("tie_row1 is undefined")
    
    if is_value_defined(dut.tie_row2.value):
        row2 = int(dut.tie_row2.value)
    else:
        raise TestFailure("tie_row2 is undefined")

    # Expected: card1 row 2 (third row) and card2 row 3 (fourth row) tie
    # Row indices are 0-based in the module
    expected_row1 = 2
    expected_row2 = 3

    if row1 != expected_row1:
        raise TestFailure(f"Expected tie_row1={expected_row1}, got {row1}")
    if row2 != expected_row2:
        raise TestFailure(f"Expected tie_row2={expected_row2}, got {row2}")

    dut._log.info("Test passed: Tie detected between card1 row 2 and card2 row 3")