import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 200

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

def to_binary_marker(val, is_tuple):
    if is_tuple:
        return 0xFF00 | (val & 0xFF)
    return val & 0xFF

def pack_array(vals, bits=16):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

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

async def write_input_array(dut, vals, width=DATA_WIDTH, is_packed=False):
    if is_packed:
        packed = 0
        for i, v in enumerate(vals):
            packed |= (clamp_to_width(v, width) & ((1 << width) - 1)) << (i * width)
        dut.input_data.value = packed
    else:
        for i, v in enumerate(vals):
            if has_signal(dut, f'input_data_{i}'):
                getattr(dut, f'input_data_{i}').value = clamp_to_width(v, width)
            elif hasattr(dut.input_data, '__len__'):
                dut.input_data[i].value = clamp_to_width(v, width)
            else:
                raise TestFailure("Cannot access input_data array")

def verify_output(output_len, output_data_list, expected):
    if output_len != len(expected):
        return False, f"Length mismatch: expected {len(expected)}, got {output_len}"
    for i in range(output_len):
        exp_val = expected[i]
        got_val = output_data_list[i]
        if got_val != exp_val:
            return False, f"Index {i}: expected {exp_val}, got {got_val}"
    return True, "OK"

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_remove_tuples(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')

    # Map test cases to HDL input format
    # Tuple (4,6) is represented as two elements with 0xFF marker
    test_cases = [
        {
            'desc': 'Test 1: (1, 5, 7, (4, 6), 10)',
            'input': [0x0001, 0x0005, 0x0007, 0xFF04, 0xFF06, 0x000A],
            'input_len': 6,
            'expected': [1, 5, 7, 10]
        },
        {
            'desc': 'Test 2: (2, 6, 8, (5, 7), 11)',
            'input': [0x0002, 0x0006, 0x0008, 0xFF05, 0xFF07, 0x000B],
            'input_len': 6,
            'expected': [2, 6, 8, 11]
        },
        {
            'desc': 'Test 3: (3, 7, 9, (6, 8), 12)',
            'input': [0x0003, 0x0007, 0x0009, 0xFF06, 0xFF08, 0x000C],
            'input_len': 6,
            'expected': [3, 7, 9, 12]
        },
        {
            'desc': 'Test 4: (3, 7, 9, (6, 8), (5,12), 12)',
            'input': [0x0003, 0x0007, 0x0009, 0xFF06, 0xFF08, 0xFF05, 0xFF0C, 0x000C],
            'input_len': 8,
            'expected': [3, 7, 9, 12]
        }
    ]

    passed = 0
    failed = 0

    for tc in test_cases:
        cocotb.log.info(f"Running: {tc['desc']}")
        try:
            # Check if input_data is packed or unpacked
            is_packed = False
            if hasattr(dut.input_data, 'value') and hasattr(dut.input_data.value, 'integer'):
                is_packed = True
            
            await write_input_array(dut, tc['input'], is_packed=is_packed)
            
            if is_seq:
                dut.input_len.value = tc['input_len']
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                dut.input_len.value = tc['input_len']
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.output_len.value):
                raise TestFailure("Output length undefined")
            
            out_len = int(dut.output_len.value)
            out_data_list = []
            for i in range(out_len):
                if has_signal(dut, f'output_data_{i}'):
                    val = int(getattr(dut, f'output_data_{i}').value)
                elif hasattr(dut.output_data, '__len__'):
                    val = int(dut.output_data[i].value)
                else:
                    # Try packed access (assuming 16-bit values)
                    full_val = int(dut.output_data.value)
                    val = (full_val >> (i * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1)
                # Only consider lower 8 bits as per spec
                val = val & 0xFF
                out_data_list.append(val)
            
            is_ok, msg = verify_output(out_len, out_data_list, tc['expected'])
            if not is_ok:
                raise TestFailure(f"{tc['desc']}: {msg}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
