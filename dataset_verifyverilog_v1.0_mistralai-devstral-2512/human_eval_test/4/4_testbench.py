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

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return max_val if v > max_val else (0 if v < 0 else v)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_mean_absolute_deviation(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic path
        pass

    # Test cases: (inputs_scaled, expected_result_scaled, description)
    # Inputs are scaled by 256 (Q8.8 -> Q8.0 for input, output is Q8.8)
    # Python calculation:
    # 1. [1.0, 2.0, 3.0] -> sum=6.0, mean=2.0, abs diffs=[1.0, 0.0, 1.0], sum=2.0, mad=2.0/3.0=0.666...
    #    Scaled: inputs [256, 512, 768]. sum=1536. mean=1536/3=512. abs diffs [256, 0, 256]. sum=512. mad=512/3 = 170.66... -> Integer 170.
    #    Expected Python float: 0.6666 -> scaled 170.666. Integer result 170. (Note: precision loss expected)
    test_cases = [
        ([256, 512, 768], 170, "[1.0, 2.0, 3.0]"), 
        ([256, 512, 768, 1024], 256, "[1.0, 2.0, 3.0, 4.0]"), # Mean=2.5 (640). Diffs: [384, 128, 128, 384] sum=1024. MAD=256.
        ([256, 512, 768, 1024, 1280], 307, "[1.0, 2.0, 3.0, 4.0, 5.0]"), # Mean=3.0 (768). Diffs: [512, 256, 0, 256, 512] sum=1536. MAD=307.2 -> 307
    ]

    passed = 0
    failed = 0

    for i, (inputs, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs to array
            if has_signal(dut, 'arr'):
                for idx, val in enumerate(inputs):
                    dut.arr[idx].value = clamp_to_width(val, 8)
            else:
                # Unpacked array ports
                for idx, val in enumerate(inputs):
                    getattr(dut, f'arr_{idx}').value = clamp_to_width(val, 8)
            
            # Set length
            dut.len.value = len(inputs)
            
            if has_signal(dut, 'clk'):
                # Sequential logic
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined")
                
                result = int(dut.result.value)
            else:
                # Combinational logic
                await Timer(10, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined")
                result = int(dut.result.value)

            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")