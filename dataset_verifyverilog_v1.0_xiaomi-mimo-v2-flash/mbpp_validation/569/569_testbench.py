import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
    if has_signal(dut, 'sublist_end'): dut.sublist_end.value = 0
    if has_signal(dut, 'list_end'): dut.list_end.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def feed_string_data(dut, string_lists):
    """Feed strings as first ASCII char with control flags"""
    for sublist in string_lists:
        for s in sublist:
            if s and len(s) > 0:
                char = ord(s[0])
                dut.data_in.value = clamp_to_width(char, 8)
                dut.valid_in.value = 1
                dut.sublist_end.value = 0
                dut.list_end.value = 0
                await RisingEdge(dut.clk)
        # End of sublist
        dut.valid_in.value = 0
        dut.sublist_end.value = 1
        await RisingEdge(dut.clk)
        dut.sublist_end.value = 0
        await RisingEdge(dut.clk)
    # End of list
    dut.list_end.value = 1
    await RisingEdge(dut.clk)
    dut.list_end.value = 0
    await RisingEdge(dut.clk)

async def collect_output_data(dut, max_items=100):
    """Collect output characters into lists"""
    result = []
    current_sublist = []
    for _ in range(max_items):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'valid_out') and is_value_defined(dut.valid_out.value):
            if int(dut.valid_out.value) == 1:
                char_val = int(dut.data_out.value)
                if 32 <= char_val <= 126:
                    current_sublist.append(chr(char_val))
        if has_signal(dut, 'out_sublist_end') and is_value_defined(dut.out_sublist_end.value):
            if int(dut.out_sublist_end.value) == 1:
                if current_sublist:
                    result.append(current_sublist)
                    current_sublist = []
        if has_signal(dut, 'out_list_end') and is_value_defined(dut.out_list_end.value):
            if int(dut.out_list_end.value) == 1:
                if current_sublist:
                    result.append(current_sublist)
                break
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_sublist_sorter(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([['green', 'orange'], ['black', 'white'], ['white', 'black', 'orange']],
         [['green', 'orange'], ['black', 'white'], ['black', 'orange', 'white']]),
        ([['green', 'orange'], ['black'], ['green', 'orange'], ['white']],
         [['green', 'orange'], ['black'], ['green', 'orange'], ['white']]),
        ([['a','b'],['d','c'],['g','h'],['f','e']],
         [['a','b'],['c','d'],['g','h'],['e','f']])
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_lists, expected_lists) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {len(input_lists)} sublists")
        try:
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed input
            await feed_string_data(dut, input_lists)
            
            # Wait
            await wait_for_done(dut, max_cycles=5000)
            
            # Collect output
            result_chars = await collect_output_data(dut, max_items=100)
            
            # Convert chars to strings (match by first char)
            result_full = []
            for sublist in result_chars:
                full_sublist = []
                for char in sublist:
                    found = False
                    for orig in input_lists:
                        for s in orig:
                            if s and s[0] == char and s not in full_sublist:
                                full_sublist.append(s)
                                found = True
                                break
                        if found:
                            break
                    if not found:
                        full_sublist.append(char)
                result_full.append(full_sublist)
            
            # Validate
            if len(result_full) != len(expected_lists):
                raise TestFailure(f"Expected {len(expected_lists)} sublists, got {len(result_full)}")
            
            for j, (got, exp) in enumerate(zip(result_full, expected_lists)):
                if sorted(got) != sorted(exp):
                    raise TestFailure(f"Sublist {j}: Expected {exp}, got {got}")
            
            passed += 1
            cocotb.log.info(f"Test {i+1} PASSED")
            
            await reset_dut(dut, cycles=3)
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
            await reset_dut(dut, cycles=3)
    
    if failed:
        raise TestFailure(f"{failed} failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")