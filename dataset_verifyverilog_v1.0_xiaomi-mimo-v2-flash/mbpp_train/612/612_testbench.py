import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_ROWS = 8
MAX_COLS = 8
CLK_NS = 10
MAX_CYCLES = 128

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_row(vals, bits=8, max_len=8):
    r = 0
    for i, v in enumerate(vals):
        if i >= max_len:
            break
        r |= (clamp_to_width(v, bits) & ((1<<bits)-1)) << (i*bits)
    return r

async def write_array_to_dut(dut, arr_2d, num_rows, num_cols):
    """Write 2D array to dut.arr signals"""
    # Check if flattened or 2D
    try:
        # Try accessing arr[0][0]
        test_signal = getattr(dut, f'arr_0_0')
        flattened = True
    except AttributeError:
        flattened = False
    except TypeError:
        flattened = False
    
    if flattened:
        for i in range(min(num_rows, MAX_ROWS)):
            for j in range(min(num_cols, MAX_COLS)):
                sig_name = f'arr_{i}_{j}'
                if has_signal(dut, sig_name):
                    val = arr_2d[i][j] if i < len(arr_2d) and j < len(arr_2d[i]) else 0
                    getattr(dut, sig_name).value = clamp_to_width(val, DATA_WIDTH)
    else:
        # Assume multi-dimensional
        try:
            # This is complex in Verilog, so we assume flattened naming
            for i in range(min(num_rows, MAX_ROWS)):
                for j in range(min(num_cols, MAX_COLS)):
                    sig_name = f'arr_{i}_{j}'
                    if has_signal(dut, sig_name):
                        val = arr_2d[i][j] if i < len(arr_2d) and j < len(arr_2d[i]) else 0
                        getattr(dut, sig_name).value = clamp_to_width(val, DATA_WIDTH)
        except:
            pass

async def read_transposed_outputs(dut):
    """Read transposed outputs from dut"""
    outputs = []
    for i in range(MAX_COLS):  # Max possible output rows
        sig_name = f'transposed_{i}'
        if has_signal(dut, sig_name):
            val = int(getattr(dut, sig_name).value)
            outputs.append(val)
        else:
            outputs.append(0)
    
    if has_signal(dut, 'num_transposed_cols'):
        num_cols = int(dut.num_transposed_cols.value)
    else:
        num_cols = 0
    
    return outputs, num_cols

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_transpose(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational, just wait for stability
        await Timer(100, units='ns')
    
    test_cases = [
        (   # Test 1: 3x2
            [[ord('x'), ord('y')], [ord('a'), ord('b')], [ord('m'), ord('n')]],
            3, 2,
            [[ord('x'), ord('a'), ord('m')], [ord('y'), ord('b'), ord('n')]],
            "3x2 chars"
        ),
        (   # Test 2: 4x2
            [[1, 2], [3, 4], [5, 6], [7, 8]],
            4, 2,
            [[1, 3, 5, 7], [2, 4, 6, 8]],
            "4x2 nums"
        ),
        (   # Test 3: 3x3 (Note: original had 3 elements per sublist, transposing 3x3)
            [[ord('x'), ord('y'), ord('z')], [ord('a'), ord('b'), ord('c')], [ord('m'), ord('n'), ord('o')]],
            3, 3,
            [[ord('x'), ord('a'), ord('m')], [ord('y'), ord('b'), ord('n')], [ord('z'), ord('c'), ord('o')]],
            "3x3 chars"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, n_rows, n_cols, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} ({n_rows}x{n_cols})")
        
        try:
            # Write inputs
            await write_array_to_dut(dut, input_arr, n_rows, n_cols)
            
            if has_signal(dut, 'num_rows'):
                dut.num_rows.value = clamp_to_width(n_rows, 4)
            if has_signal(dut, 'num_cols'):
                dut.num_cols.value = clamp_to_width(n_cols, 4)
            
            # Start operation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await Timer(10, units='ns')  # Combinational settle
            
            # Read outputs
            outputs, num_trans_cols = await read_transposed_outputs(dut)
            
            # Decode packed outputs
            decoded_outputs = []
            for out_idx in range(len(expected)):
                if out_idx < num_trans_cols:
                    packed_val = outputs[out_idx]
                    row = []
                    for j in range(n_rows):
                        # Extract 8-bit element
                        elem = (packed_val >> (j * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1)
                        row.append(elem)
                    decoded_outputs.append(row)
                else:
                    decoded_outputs.append([])
            
            # Validate
            expected_rows = len(expected)
            if num_trans_cols != expected_rows:
                raise TestFailure(f"Expected {expected_rows} output rows, got {num_trans_cols}")
            
            for r_idx in range(expected_rows):
                for c_idx in range(n_rows):  # Expected row length is n_rows
                    if r_idx >= len(decoded_outputs) or c_idx >= len(decoded_outputs[r_idx]):
                        raise TestFailure(f"Output row {r_idx} is too short")
                    
                    exp_val = expected[r_idx][c_idx]
                    out_val = decoded_outputs[r_idx][c_idx]
                    
                    if exp_val != out_val:
                        raise TestFailure(
                            f"Mismatch at [{r_idx}][{c_idx}]: expected {exp_val}, got {out_val}"
                        )
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} ({desc}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
