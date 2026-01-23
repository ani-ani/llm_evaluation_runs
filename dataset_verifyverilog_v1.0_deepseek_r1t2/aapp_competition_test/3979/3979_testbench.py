import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# HELPER FUNCTIONS FOR TESTBENCH
# ============================================================================

def pack_word(letters, max_len=8):
    """
    Pack a list of letters (ints 1..8) into a 32‑bit word.
    Each letter occupies 4 bits, LSB is the first letter.
    """
    packed = 0
    for i, val in enumerate(letters):
        if i >= max_len:
            break
        packed |= (val & 0xF) << (4 * i)
    return packed

def parse_input(input_str):
    """Parse the problem input string into a list of test cases."""
    lines = input_str.strip().split('\n')
    idx = 0
    test_cases = []
    while idx < len(lines):
        if not lines[idx].strip():
            idx += 1
            continue
        n, m = map(int, lines[idx].split())
        idx += 1
        words = []
        for _ in range(n):
            parts = list(map(int, lines[idx].split()))
            length = parts[0]
            letters = parts[1:]
            words.append((length, letters))
            idx += 1
        test_cases.append((n, m, words))
    return test_cases

def compute_expected(n, m, words):
    """Compute the expected result using the Python algorithm (brute force)."""
    # Convert words to list of lists
    word_lists = [w[1] for w in words]
    # Try all subsets of letters 1..m
    for mask in range(1 << m):
        ok = True
        for i in range(n-1):
            w1 = word_lists[i]
            w2 = word_lists[i+1]
            # Compare under mask
            len1, len2 = len(w1), len(w2)
            diff_found = False
            for j in range(min(len1, len2)):
                a, b = w1[j], w2[j]
                if a != b:
                    cap_a = (mask >> (a-1)) & 1
                    cap_b = (mask >> (b-1)) & 1
                    if cap_a == cap_b:
                        if a < b:
                            pass
                        else:
                            ok = False
                    elif cap_a < cap_b:  # a large, b small -> a < b
                        pass
                    else:  # a small, b large -> a > b
                        ok = False
                    diff_found = True
                    break
            if not diff_found:
                if len1 > len2:
                    ok = False
            if not ok:
                break
        if ok:
            # Return the set of letters to capitalize
            cap_letters = [j+1 for j in range(m) if (mask >> j) & 1]
            return True, cap_letters
    return False, []

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bookland_ordering(dut):
    """Test the bookland ordering module with scaled‑down examples."""

    # Configuration
    CLK_PERIOD_NS = 10
    MAX_WORDS = 8
    MAX_M = 8

    # Detect if the module has a clock
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')

    # Start clock if present
    if has_clk:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())

    # Reset sequence (active‑low reset)
    if has_rst:
        dut.rst_n.value = 0
        if has_start:
            dut.start.value = 0
        for _ in range(2):
            if has_clk:
                await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        if has_clk:
            await RisingEdge(dut.clk)
    else:
        # If no reset, just wait a bit
        await Timer(100, units='ns')

    # Input test cases (scaled to fit within MAX_WORDS and MAX_M)
    # We use the first three examples from the problem statement.
    # They are already within limits: n=4,6,4; m=3,5,3; word lengths <=4.
    test_inputs = [
        "4 3\n1 2\n1 1\n3 1 3 2\n2 1 1",
        "6 5\n2 1 2\n2 1 2\n3 1 2 3\n2 1 5\n2 4 4\n2 4 4",
        "4 3\n4 3 2 2 1\n3 1 1 3\n3 2 3 3\n2 3 1"
    ]
    expected_outputs = [
        (True, [2, 3]),
        (True, []),
        (False, [])
    ]

    test_cases = parse_input('\n'.join(test_inputs))

    for case_idx, ((n, m, words), (exp_yes, exp_letters)) in enumerate(zip(test_cases, expected_outputs)):
        dut._log.info(f"\n=== Test Case {case_idx+1}: n={n}, m={m} ===")

        # Load the words into the DUT
        # We assume the DUT has arrays word_len[0:7] and word_data[0:7]
        for i in range(MAX_WORDS):
            # Clear first
            if has_signal(dut, f'word_len_{i}'):
                getattr(dut, f'word_len_{i}').value = 0
                getattr(dut, f'word_data_{i}').value = 0
            elif has_signal(dut, 'word_len') and has_signal(dut, 'word_data'):
                # Array style
                try:
                    dut.word_len[i].value = 0
                    dut.word_data[i].value = 0
                except (AttributeError, TypeError):
                    pass

        # Fill with actual data
        for i, (length, letters) in enumerate(words):
            if i >= MAX_WORDS:
                break
            # Pack the letters
            packed = pack_word(letters, max_len=8)
            # Write to DUT
            if has_signal(dut, f'word_len_{i}'):
                getattr(dut, f'word_len_{i}').value = clamp_to_width(length, 4)
                getattr(dut, f'word_data_{i}').value = packed
            elif has_signal(dut, 'word_len') and has_signal(dut, 'word_data'):
                dut.word_len[i].value = clamp_to_width(length, 4)
                dut.word_data[i].value = packed
            else:
                raise TestFailure(f"Cannot find word signals for index {i}")

        # Set n and m
        if has_signal(dut, 'n'):
            dut.n.value = clamp_to_width(n, 4)
        if has_signal(dut, 'm'):
            dut.m.value = clamp_to_width(m, 4)

        # Wait for any propagation
        await Timer(100, units='ns')

        # Pulse start
        if has_start:
            dut.start.value = 1
            if has_clk:
                await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # If no start signal, assume computation starts immediately
            pass

        # Wait for done (if present) or a reasonable time
        if has_done:
            max_cycles = 10000
            for _ in range(max_cycles):
                if has_clk:
                    await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done in test case {case_idx+1}")
        else:
            # Combinational module – wait for propagation
            await Timer(500, units='ns')

        # Read outputs
        if not is_value_defined(dut.yes.value):
            raise TestFailure(f"Output 'yes' is undefined in test case {case_idx+1}")
        yes_val = int(dut.yes.value)

        k_val = 0
        letters_out_val = 0
        if has_signal(dut, 'k') and is_value_defined(dut.k.value):
            k_val = int(dut.k.value)
        if has_signal(dut, 'letters_out') and is_value_defined(dut.letters_out.value):
            letters_out_val = int(dut.letters_out.value)

        # Extract capitalized letters from bitmask
        cap_letters = []
        for bit in range(MAX_M):
            if (letters_out_val >> bit) & 1:
                cap_letters.append(bit + 1)  # letters are 1‑indexed

        # Verify
        if yes_val != (1 if exp_yes else 0):
            raise TestFailure(f"Test {case_idx+1}: expected yes={exp_yes}, got {yes_val}")

        if exp_yes:
            # Check that the set of capitalized letters works (not necessarily minimal)
            # We can simulate quickly with the expected function to ensure correctness
            ok, expected_set = compute_expected(n, m, words)
            if not ok:
                raise TestFailure(f"Test {case_idx+1}: computed no solution, but DUT says yes")
            # The DUT's set may be different; we just check that it is a valid set
            # Re‑run the ordering check with the DUT's set
            mask = 0
            for l in cap_letters:
                if 1 <= l <= m:
                    mask |= 1 << (l-1)
            # Validate with mask
            valid = True
            for i in range(n-1):
                w1 = words[i][1]
                w2 = words[i+1][1]
                len1, len2 = len(w1), len(w2)
                diff_found = False
                for j in range(min(len1, len2)):
                    a, b = w1[j], w2[j]
                    if a != b:
                        cap_a = (mask >> (a-1)) & 1
                        cap_b = (mask >> (b-1)) & 1
                        if cap_a == cap_b:
                            if a < b:
                                pass
                            else:
                                valid = False
                        elif cap_a < cap_b:
                            pass
                        else:
                            valid = False
                        diff_found = True
                        break
                if not diff_found:
                    if len1 > len2:
                        valid = False
                if not valid:
                    break
            if not valid:
                raise TestFailure(f"Test {case_idx+1}: DUT output set does not produce a valid ordering")
            dut._log.info(f"  PASS: yes=1, k={k_val}, letters={cap_letters}")
        else:
            if yes_val != 0:
                raise TestFailure(f"Test {case_idx+1}: expected yes=0, got 1")
            dut._log.info(f"  PASS: yes=0")

    dut._log.info("\nAll tests passed!")
