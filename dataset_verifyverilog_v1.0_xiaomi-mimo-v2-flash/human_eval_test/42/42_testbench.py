import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 8
CLK_NS = 10
MAX_CYCLES = 100

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width, max_len):
    for i in range(max_len):
        val = vals[i] if i < len(vals) else 0
        # Individual assignment for each array element
        if hasattr(dut, name):
            if isinstance(getattr(dut, name), list):
                getattr(dut, name)[i].value = clamp_to_width(val, width)
            else:
                # Try arr_0, arr_1, etc.
                try:
                    getattr(dut, f"{name}_{i}").value = clamp_to_width(val, width)
                except AttributeError:
                    # Try arr_0_0 pattern
                    try:
                        getattr(dut, f"{name}_{i}_0").value = clamp_to_width(val, width)
                    except AttributeError:
                        pass

def read_array(dut, name, width, max_len):
    results = []
    for i in range(max_len):
        try:
            if hasattr(dut, name):
                if isinstance(getattr(dut, name), list):
                    val = int(getattr(dut, name)[i].value)
                else:
                    try:
                        val = int(getattr(dut, f"{name}_{i}").value)
                    except AttributeError:
                        try:
                            val = int(getattr(dut, f"{name}_{i}_0").value)
                        except AttributeError:
                            val = 0
            else:
                val = 0
            results.append(val)
        except:
            results.append(0)
    return results

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_incr_list(dut):
    # Check if sequential (has clk)
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([], 0, "empty array"),
        ([3, 2, 1], 3, "small array"),
        ([5, 2, 5, 2, 3, 3, 9, 0], 8, "full array"),
        ([255, 0, 100], 3, "overflow case"),
        ([0, 0, 0, 0, 0, 0, 0, 0], 8, "all zeros"),
        ([127, 128, 129, 130], 4, "mid values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp_len, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {inp}")
        try:
            # Compute expected output
            expected = [(x + 1) & 0xFF for x in inp]
            
            # Write input array
            await write_array(dut, 'arr_in', inp, DATA_WIDTH, MAX_LEN)
            
            # Write length if it exists as separate signal
            if has_signal(dut, 'len'):
                dut.len.value = exp_len
            
            if is_seq:
                # Assert start pulse
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=20)
            else:
                # Combinational - wait for settle
                await Timer(100, units='ns')
            
            # Read output array
            if has_signal(dut, 'arr_out'):
                result = read_array(dut, 'arr_out', DATA_WIDTH, MAX_LEN)
            else:
                # Try reading arr_out_0, arr_out_1, etc.
                result = []
                for idx in range(MAX_LEN):
                    try:
                        val = int(getattr(dut, f'arr_out_{idx}').value)
                        result.append(val)
                    except:
                        try:
                            val = int(getattr(dut, f'arr_out_{idx}_0').value)
                            result.append(val)
                        except:
                            result.append(0)
            
            # Check results
            if exp_len == 0:
                # Empty array case - all outputs should be 0
                for idx, val in enumerate(result[:MAX_LEN]):
                    if val != 0:
                        raise TestFailure(f"Index {idx} should be 0, got {val}")
            else:
                # Check each element
                for idx in range(exp_len):
                    if idx >= len(result):
                        raise TestFailure(f"Result array too short")
                    exp_val = expected[idx]
                    act_val = result[idx]
                    if act_val != exp_val:
                        raise TestFailure(f"Index {idx}: expected {exp_val}, got {act_val}")
                
                # Elements beyond len should be 0
                for idx in range(exp_len, MAX_LEN):
                    if idx < len(result) and result[idx] != 0:
                        raise TestFailure(f"Index {idx} (beyond len) should be 0, got {result[idx]}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Output = {result[:exp_len] if exp_len>0 else []}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
