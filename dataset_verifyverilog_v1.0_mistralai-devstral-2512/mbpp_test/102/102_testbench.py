import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def string_to_bytes(s, max_len=16):
    return [ord(c) for c in s[:max_len]]

def bytes_to_string(b):
    return ''.join(chr(x) for x in b if x != 0 and x != 0x5F)

def camel_case_result(inp):
    parts = inp.split('_')
    return ''.join(p.capitalize() if i==0 else p.capitalize() for i,p in enumerate(parts))

async def write_input_str(dut, s):
    bytes_data = string_to_bytes(s)
    for i in range(16):
        val = bytes_data[i] if i < len(bytes_data) else 0
        dut.input_str[i].value = clamp_to_width(val, 8)
    dut.len.value = clamp_to_width(len(bytes_data), 4)

async def read_output_str(dut):
    result_len = int(dut.result_len.value)
    bytes_out = []
    for i in range(result_len):
        bytes_out.append(int(dut.output_str[i].value))
    return bytes_out

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=32):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_snake_to_camel(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        ('python_program', 'PythonProgram'),
        ('python_language', 'PythonLanguage'),
        ('programming_language', 'ProgrammingLanguage'),
        ('hello_world', 'HelloWorld'),
        ('test_case_123', 'TestCase123'),
        ('single', 'Single'),
        ('a_b_c', 'ABC'),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{inp}' -> '{expected}'")
        try:
            await write_input_str(dut, inp)
            
            if has_signal(dut, 'clk'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result_len.value):
                raise TestFailure("result_len undefined")
            result_len = int(dut.result_len.value)
            
            bytes_out = await read_output_str(dut)
            result = bytes_to_string(bytes_out)
            
            if result != expected:
                raise TestFailure(f"Expected '{expected}' (len={len(expected)}), got '{result}' (len={len(result)})")
            
            passed += 1
            cocotb.log.info(f"  PASS: '{result}'")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        await Timer(50, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed out of {passed+failed}")