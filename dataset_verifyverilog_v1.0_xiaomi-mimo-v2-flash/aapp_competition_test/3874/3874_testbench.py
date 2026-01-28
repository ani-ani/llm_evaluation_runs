import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_FILES = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 256

# Include helpers

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

def char_to_ascii(c):
    return ord(c)

def ascii_to_char(v):
    return chr(v)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_files(dut, files, lengths):
    """Write fixed 16-char arrays to files[i][j] signals"""
    for i, (file_str, file_len) in enumerate(zip(files, lengths)):
        for j in range(MAX_LEN):
            signal = getattr(dut, f'files_{i}_{j}')
            if j < file_len:
                val = char_to_ascii(file_str[j])
            else:
                val = 0
            signal.value = clamp_to_width(val, DATA_WIDTH)
        getattr(dut, f'lengths_{i}').value = file_len

async def write_indices(dut, indices):
    """Write delete indices to delete_idx[i] signals"""
    for i in range(4):
        signal = getattr(dut, f'delete_idx_{i}')
        if i < len(indices):
            signal.value = clamp_to_width(indices[i], 4)
        else:
            signal.value = 0

async def read_pattern(dut):
    """Read pattern from result[i] signals"""
    pattern_chars = []
    for j in range(MAX_LEN):
        signal = getattr(dut, f'result_{j}')
        val = int(signal.value)
        if val == 0:
            break
        pattern_chars.append(ascii_to_char(val))
    return ''.join(pattern_chars)

def simulate_pattern(files, delete_indices, lengths):
    """Python simulation to verify expected result"""
    # Get delete files
    delete_files = [files[i] for i in delete_indices]
    delete_lengths = [lengths[i] for i in delete_indices]
    
    # Check all delete files have same length
    if len(set(delete_lengths)) != 1:
        return None, 0, False
    
    L = delete_lengths[0]
    
    # Build pattern
    pattern = []
    for pos in range(L):
        chars = set(delete_files[i][pos] for i in range(len(delete_files)))
        if len(chars) == 1:
            pattern.append(list(chars)[0])
        else:
            pattern.append('?')
    
    pattern_str = ''.join(pattern)
    
    # Check non-delete files
    for i, file_str in enumerate(files):
        if i in delete_indices:
            continue
        if lengths[i] != L:
            continue
        # Check if matches pattern (ignoring '?')
        matches = True
        for pos in range(L):
            if pattern_str[pos] != '?' and pattern_str[pos] != file_str[pos]:
                matches = False
                break
        if matches:
            return pattern_str, L, False
    
    return pattern_str, L, True

class TestCase:
    def __init__(self, files, delete_indices, lengths, description):
        self.files = files
        self.delete_indices = delete_indices
        self.lengths = lengths
        self.description = description
        self.expected_pattern, self.expected_len, self.expected_valid = simulate_pattern(files, delete_indices, lengths)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pattern_finder(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        TestCase(
            files=["ab", "ac", "cd"],
            delete_indices=[0, 1],
            lengths=[2, 2, 2],
            description="Example 1: ab, ac -> a?"
        ),
        TestCase(
            files=["test", "tezt", "test.", ".est", "tes."],
            delete_indices=[0, 3, 4],
            lengths=[4, 4, 5, 4, 4],
            description="Example 2: test, .est, tes. -> ?es?"
        ),
        TestCase(
            files=["a", "b", "c", "dd"],
            delete_indices=[0, 1, 2, 3],
            lengths=[1, 1, 1, 2],
            description="Example 3: Mixed lengths -> No"
        ),
        TestCase(
            files=[".svn", ".git", "....", "...", "..", "."],
            delete_indices=[0, 1, 2],
            lengths=[4, 4, 4, 3, 2, 1],
            description="Example 4: .svn, .git, .... -> .???"
        ),
        TestCase(
            files=[".b", ".c", "dbt", "e."],
            delete_indices=[1, 3],
            lengths=[2, 2, 3, 2],
            description="Example 5: .c, e. -> No"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {tc.description}")
        try:
            # Write inputs
            await write_files(dut, tc.files, tc.lengths)
            await write_indices(dut, tc.delete_indices)
            
            if is_seq:
                dut.num_files.value = len(tc.files)
                dut.num_delete.value = len(tc.delete_indices)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Valid signal undefined")
            
            valid = int(dut.valid.value)
            result_len = int(dut.result_len.value)
            pattern = await read_pattern(dut)
            
            # Verify
            if tc.expected_valid:
                if valid != 1:
                    raise TestFailure(f"Expected valid=1, got {valid}")
                if result_len != tc.expected_len:
                    raise TestFailure(f"Expected len={tc.expected_len}, got {result_len}")
                if pattern != tc.expected_pattern:
                    raise TestFailure(f"Expected pattern='{tc.expected_pattern}', got '{pattern}'")
            else:
                if valid != 0:
                    raise TestFailure(f"Expected valid=0, got {valid}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        if is_seq:
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed")
