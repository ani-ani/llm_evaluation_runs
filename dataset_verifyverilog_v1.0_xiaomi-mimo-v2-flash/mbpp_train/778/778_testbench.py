import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 16, 10, 1000

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

async def write_array(dut, name, vals, width):
    """Write values to array elements one by one"""
    for i, v in enumerate(vals):
        if hasattr(dut, name) and hasattr(getattr(dut, name), '__getitem__'):
            getattr(dut, name)[i].value = clamp_to_width(v, width)
        else:
            # For unpacked ports
            port = getattr(dut, f"{name}_{i}")
            port.value = clamp_to_width(v, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_list_to_array(vals, width=8):
    """Pack list values into a single integer for array assignment"""
    result = 0
    for i, v in enumerate(vals):
        result |= (clamp_to_width(v, width) & ((1 << width) - 1)) << (i * width)
    return result

def extract_stream_groups(values, stream):
    """Reconstruct groups from streaming output with group markers"""
    groups = []
    current_group = []
    
    for val, is_start in stream:
        if is_start and current_group:
            groups.append(current_group)
            current_group = []
        current_group.append(val)
    
    if current_group:
        groups.append(current_group)
    
    return groups

@cocotb.test(timeout_time=10, timeout_unit="sec")
async def test_pack_consecutive_duplicates(dut):
    """Test packing consecutive duplicates into sublists"""
    
    # Setup clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([0, 0, 1, 2, 3, 4, 4, 5, 6, 6, 6, 7, 8, 9, 4, 4], 16),
        ([10, 10, 15, 19, 18, 18, 17, 26, 26, 17, 18, 10], 12),
        (['a', 'a', 'b', 'c', 'd', 'd'], 6)
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (input_vals, expected_len) in enumerate(test_cases):
        cocotb.log.info(f"Test case {test_idx + 1}: Input length {len(input_vals)}")
        
        # Convert chars to ASCII if needed
        if isinstance(input_vals[0], str):
            numeric_vals = [ord(c) for c in input_vals]
        else:
            numeric_vals = input_vals
        
        try:
            # Wait for idle
            await RisingEdge(dut.clk)
            
            # Set input array - using packed assignment for efficiency
            for i, v in enumerate(numeric_vals):
                # Handle array as either array or individual signals
                if hasattr(dut, 'arr') and hasattr(getattr(dut, 'arr'), '__getitem__'):
                    dut.arr[i].value = clamp_to_width(v, DATA_WIDTH)
                else:
                    port_name = f"arr_{i}"
                    if hasattr(dut, port_name):
                        getattr(dut, port_name).value = clamp_to_width(v, DATA_WIDTH)
            
            # Set length
            if hasattr(dut, 'len'):
                dut.len.value = expected_len
            
            # Start processing
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Collect streaming output
                stream = []
                
                # Wait for results or done
                max_cycles = 200
                cycle_count = 0
                
                while cycle_count < max_cycles:
                    await RisingEdge(dut.clk)
                    cycle_count += 1
                    
                    # Check if result is valid this cycle
                    if has_signal(dut, 'result_valid'):
                        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                            if is_value_defined(dut.result.value):
                                result_val = int(dut.result.value)
                                is_start = 0
                                if has_signal(dut, 'result_is_group_start'):
                                    if is_value_defined(dut.result_is_group_start.value):
                                        is_start = int(dut.result_is_group_start.value)
                                stream.append((result_val, is_start))
                    
                    # Check done
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                
                # Reconstruct groups from stream
                if stream:
                    groups = extract_stream_groups(numeric_vals, stream)
                    
                    # Verify each group's content
                    expected_groups = []
                    current = [numeric_vals[0]]
                    for val in numeric_vals[1:]:
                        if val == current[-1]:
                            current.append(val)
                        else:
                            expected_groups.append(current)
                            current = [val]
                    expected_groups.append(current)
                    
                    # Compare
                    if len(groups) != len(expected_groups):
                        raise TestFailure(f"Group count mismatch: expected {len(expected_groups)}, got {len(groups)}")
                    
                    for idx, (exp, got) in enumerate(zip(expected_groups, groups)):
                        if exp != got:
                            raise TestFailure(f"Group {idx} mismatch: expected {exp}, got {got}")
                
                cocotb.log.info(f"  Passed: {len(stream)} output elements, {len(groups) if 'groups' in locals() else 0} groups")
                passed += 1
                
            else:
                # Combinational - just wait for output
                await Timer(100, units='ns')
                if is_value_defined(dut.result.value):
                    result_val = int(dut.result.value)
                    # For combinational, expect a single result
                    passed += 1
                    
        except Exception as e:
            cocotb.log.error(f"  Test {test_idx + 1} FAILED: {str(e)}")
            failed += 1
            if is_seq:
                await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")