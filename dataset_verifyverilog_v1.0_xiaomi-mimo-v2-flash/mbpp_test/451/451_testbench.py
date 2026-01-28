import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
    raise TestFailure(f"Timeout waiting for done signal after {max_cycles} cycles")

async def write_input_string(dut, text):
    # Convert string to bytes
    byte_list = [ord(c) for c in text]
    # Clamp length
    length = len(byte_list)
    if length > MAX_LEN:
        length = MAX_LEN
        byte_list = byte_list[:MAX_LEN]
    
    # Write to dut.input_str array (index 0 to 15)
    for i in range(MAX_LEN):
        val = byte_list[i] if i < length else 0
        dut.input_str[i].value = val
    
    # Write length
    if has_signal(dut, 'length'):
        dut.length.value = length
    
    return length

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_remove_whitespaces(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational case (should be rare for this algorithm, but handled)
        await Timer(100, units='ns')

    test_cases = [
        (' Google    Flutter ', 'GoogleFlutter'),
        (' Google    Dart ', 'GoogleDart'),
        (' iOS    Swift ', 'iOSSwift'),
        ('    ', ''),
        ('NoSpaces', 'NoSpaces'),
        (' a ', 'a'),
    ]

    passed = 0
    failed = 0

    for idx, (input_text, expected_text) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: Input='{input_text}' -> Expected='{expected_text}'")
        try:
            # Write input
            input_len = await write_input_string(dut, input_text)
            
            # Trigger
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Wait for done
            if has_signal(dut, 'done'):
                await wait_for_done(dut)
            else:
                # Combinational: wait for inputs to settle
                await Timer(50, units='ns')
            
            # Read output
            if not has_signal(dut, 'output_str'):
                raise TestFailure("Signal 'output_str' not found")
            
            # Read length
            if has_signal(dut, 'output_len'):
                out_len = safe_int(dut.output_len.value)
            else:
                # Infer length from non-zero bytes
                out_len = 0
                for i in range(MAX_LEN):
                    if safe_int(dut.output_str[i].value) != 0:
                        out_len = i + 1
            
            # Read string
            result_bytes = []
            for i in range(MAX_LEN):
                val = safe_int(dut.output_str[i].value)
                if i < out_len:
                    result_bytes.append(val)
                elif val != 0:
                    # Extra non-zero byte found, treat as part of string if length signal missing
                    if not has_signal(dut, 'output_len'):
                        result_bytes.append(val)
            
            result_text = ''.join(chr(b) for b in result_bytes)
            
            if result_text != expected_text:
                raise TestFailure(f"Expected '{expected_text}', got '{result_text}' (len {out_len})")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
