import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_HASHES = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

async def wait_for_done(dut, max_cycles=1000):
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

async def send_string(dut, s):
    for char in s:
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_treasure_map(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("(((#)((#)", [1, 2]),
        ("()((#((#(#()", [2, 2, 1]),
        ("#", None),
        ("(#)", None),
        ("(((((#(#(#(#()", [1, 1, 1, 5]),
        ("#))))", None),
        ("((#(()#(##", [1, 1, 1, 1]),
        ("##((((((()", None),
        ("(((((((((((((((((((###################", [1]*19),
        ("((#)(", None),
        ("((#)((#)((#)((#)((#)((#)((#)((#)((#)((#)((#)((#)((#)((#)((#)((##", [1]*16),
        (")((##((###", None),
        ("(#))(#(#)((((#(##((#(#((((#(##((((((#((()(()(())((()#((((#((()((((#(((((#(##)(##()((((()())(((((#(((", None),
        ("#(#(#((##((()))(((#)(#()#(((()()(()#(##(((()(((()))#(((((()(((((((()#((#((()(#(((()(()##(()(((()((#(", None),
        ("((#(", None),
        ("()#(#())()()#)(#)()##)#((()#)((#)()#())((#((((((((#)()()(()()(((((#)#(#((((#((##()(##(((#(()(#((#))#", None),
        ("((())((((#)", [3]),
        ("(#(", None),
        ("((#)(", None),
        ("(((()#(#)(", None),
        ("#((#", None),
        ("(#((((()", None),
        ("(#((", None),
        (")(((()#", None),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_str, expected_outputs) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: Input='{input_str}', Expected={expected_outputs}")
        try:
            # Prepare for new test
            if is_seq:
                await reset_dut(dut, cycles=2)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Send string
                await send_string(dut, input_str)
                
                # Wait for done or failure
                await wait_for_done(dut)
                
                # Check result
                failure = int(dut.failure.value) if has_signal(dut, 'failure') else 0
                
                if expected_outputs is None:
                    # Should fail
                    if not failure:
                        raise TestFailure(f"Expected failure but got success")
                    # Check for -1 output
                    result_defined = is_value_defined(dut.result.value)
                    if result_defined and int(dut.result.value) != -1:
                        raise TestFailure(f"Expected -1 output, got {int(dut.result.value)}")
                else:
                    # Should succeed
                    if failure:
                        raise TestFailure(f"Expected success but got failure")
                    
                    # Collect outputs
                    outputs = []
                    # Wait for result_valid pulses
                    timeout = 50
                    for _ in range(timeout):
                        await RisingEdge(dut.clk)
                        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                            val = int(dut.result.value)
                            outputs.append(val)
                    
                    if len(outputs) != len(expected_outputs):
                        raise TestFailure(f"Expected {len(expected_outputs)} outputs, got {len(outputs)}: {outputs}")
                    
                    for i, (got, exp) in enumerate(zip(outputs, expected_outputs)):
                        if got != exp:
                            raise TestFailure(f"Output {i}: expected {exp}, got {got}")
                
                passed += 1
            else:
                # Combinational - just wait
                await Timer(100, units='ns')
                # For combinational, we would read output directly, but here we assume sequential
                pass
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {idx+1}): {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR (Test {idx+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
