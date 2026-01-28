import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    v = safe_int(v, 0)
    return min((1 << bits) - 1, max(0, v))

# Array assignment helpers
def write_sublists(dut, sublists, elem_width=8, num_sublists=16, elems_per_sublist=4):
    # sublists: list of tuples/lists, each inner list length <=4, values 8-bit
    # valid_mask: assume all provided are valid
    for i in range(num_sublists):
        valid = 0
        if i < len(sublists):
            sl = sublists[i]
            valid = 1
            for j in range(elems_per_sublist):
                val = sl[j] if j < len(sl) else 0
                getattr(dut, f'input_sublists_{i}_{j}').value = clamp_to_width(val, elem_width)
        getattr(dut, f'valid_mask_{i}').value = valid

def read_output(dut, num_output=10, elem_width=8, count_width=8):
    tuples_out = []
    counts_out = []
    for i in range(num_output):
        tup = []
        for j in range(4):  # fixed 4 elements per tuple
            elem = getattr(dut, f'output_tuples_{i}_{j}').value
            if is_value_defined(elem):
                tup.append(int(elem))
        cnt = getattr(dut, f'output_counts_{i}').value
        cnt_val = int(cnt) if is_value_defined(cnt) else 0
        tuples_out.append(tuple(tup))
        counts_out.append(cnt_val)
    len_val = int(dut.output_len.value) if is_value_defined(dut.output_len.value) else 0
    return tuples_out, counts_out, len_val

def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            yield RisingEdge(dut.clk)
        else:
            yield Timer(1, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        yield RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_sublist_counter(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        CLK_NS = 10
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        dut.rst_n.value = 1  # Active high for combo

    test_cases = [
        (   # Test 1
            [[1, 3], [5, 7], [1, 3], [13, 15, 17], [5, 7], [9, 11]],
            [(1,3,0,0), (5,7,0,0), (13,15,17,0), (9,11,0,0)],  # tuples (padded with zeros to 4 elements)
            [2, 2, 1, 1, 0, 0, 0, 0, 0, 0],  # counts
            4  # len
        ),
        (   # Test 2
            [['green', 'orange'], ['black'], ['green', 'orange'], ['white']],
            # Convert strings to bytes? For simplicity, assume ASCII codes: green=103, orange=111, black=98, white=119
            # Map to 8-bit values: 'green'=103, 'orange'=111, 'black'=98, 'white'=119
            [(103,111,0,0), (98,0,0,0), (103,111,0,0), (119,0,0,0)],
            [2, 1, 1, 0, 0, 0, 0, 0, 0, 0],
            3
        ),
        (   # Test 3
            [[1, 2], [3, 4], [4, 5], [6, 7]],
            [(1,2,0,0), (3,4,0,0), (4,5,0,0), (6,7,0,0)],
            [1, 1, 1, 1, 0, 0, 0, 0, 0, 0],
            4
        )
    ]

    passed = 0
    failed = 0

    for i, (inp, exp_tuples, exp_counts, exp_len) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {inp}")
        try:
            # Write inputs
            write_sublists(dut, inp)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                max_cycles = 512
                for cycle in range(max_cycles):
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                    await RisingEdge(dut.clk)
                else:
                    raise TestFailure(f"Timeout after {max_cycles} cycles")
            else:
                await Timer(100, units='ns')

            # Read outputs
            tuples_out, counts_out, out_len = read_output(dut)
            
            if out_len != exp_len:
                raise TestFailure(f"Len mismatch: expected {exp_len}, got {out_len}")
            
            # Check tuples and counts up to out_len (assuming sorted by count desc, but test cases specific)
            # For simplicity, check that all exp tuples are present with correct counts
            # But output is sorted, so match sorted order
            for j in range(out_len):
                if tuples_out[j] != exp_tuples[j]:
                    raise TestFailure(f"Tuple {j} mismatch: expected {exp_tuples[j]}, got {tuples_out[j]}")
                if counts_out[j] != exp_counts[j]:
                    raise TestFailure(f"Count {j} mismatch: expected {exp_counts[j]}, got {counts_out[j]}")
            
            # Check remaining are zero
            for j in range(out_len, 10):
                if tuples_out[j] != (0,0,0,0):
                    raise TestFailure(f"Non-zero tuple after len at {j}")
                if counts_out[j] != 0:
                    raise TestFailure(f"Non-zero count after len at {j}")

            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
