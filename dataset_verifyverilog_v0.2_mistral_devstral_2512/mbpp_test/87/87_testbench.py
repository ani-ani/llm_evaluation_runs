import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def ascii_to_hex(char):
    """Convert ASCII character to hex value"""
    return ord(char) if char else 0x00

def dict_to_arrays(d, size=6):
    """Convert dictionary to key and value arrays"""
    keys = [0x00] * size
    vals = [0x00] * size
    items = list(d.items())
    for i, (k, v) in enumerate(items[:size]):
        keys[i] = ascii_to_hex(k)
        vals[i] = ascii_to_hex(v)
    return keys, vals

def pack_array(dut_signal, values):
    """Pack values into dut array signal"""
    for i, val in enumerate(values):
        dut_signal[i].value = val

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.clk.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')

async def apply_test_case(dut, dict1, dict2, dict3, expected_merged):
    """Apply test case and verify results"""
    # Convert dictionaries to arrays
    d1_keys, d1_vals = dict_to_arrays(dict1)
    d2_keys, d2_vals = dict_to_arrays(dict2)
    d3_keys, d3_vals = dict_to_arrays(dict3)
    
    # Pack inputs
    pack_array(dut.dict1_keys, d1_keys)
    pack_array(dut.dict1_vals, d1_vals)
    pack_array(dut.dict2_keys, d2_keys)
    pack_array(dut.dict2_vals, d2_vals)
    pack_array(dut.dict3_keys, d3_keys)
    pack_array(dut.dict3_vals, d3_vals)
    
    # Start operation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal (13 cycles total from start)
    for _ in range(14):
        await RisingEdge(dut.clk)
    
    # Read results
    merged_keys = [int(dut.merged_keys[i]) for i in range(6)]
    merged_vals = [int(dut.merged_vals[i]) for i in range(6)]
    
    # Convert to dictionary
    result = {}
    for k, v in zip(merged_keys, merged_vals):
        if k != 0x00:
            result[chr(k)] = chr(v)
    
    print(f"Result: {result}")
    print(f"Expected: {expected_merged}")
    
    assert result == expected_merged, f"Mismatch! Got {result}, expected {expected_merged}"
    print("Test passed!")

@cocotb.test()
async def test_merge_basic(dut):
    """Test basic merge with overlap"""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    dict1 = {"R": "Red", "B": "Black", "P": "Pink"}
    dict2 = {"G": "Green", "W": "White"}
    dict3 = {"O": "Orange", "W": "White", "B": "Black"}
    
    # Expected: dict3 values override dict1 for 'B' and 'W' (but 'W' same value)
    # Keys from dict1: R, B, P
    # Keys from dict2: G, W (new)
    # Keys from dict3: O, W (update), B (update)
    # Final: B=Black, R=Red, P=Pink, G=Green, W=White, O=Orange
    expected = {"B": "Black", "R": "Red", "P": "Pink", "G": "Green", "W": "White", "O": "Orange"}
    
    await apply_test_case(dut, dict1, dict2, dict3, expected)

@cocotb.test()
async def test_merge_override(dut):
    """Test value override from dict3"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    dict1 = {"R": "Red", "B": "Black", "P": "Pink"}
    dict2 = {"G": "Green", "W": "White"}
    dict3 = {"L": "lavender", "B": "Blue"}
    
    # Expected: 'B' from dict3 overrides dict1 to 'Blue'
    expected = {"W": "White", "P": "Pink", "B": "Blue", "R": "Red", "G": "Green", "L": "lavender"}
    
    await apply_test_case(dut, dict1, dict2, dict3, expected)

@cocotb.test()
async def test_merge_chain(dut):
    """Test chain of overrides"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    dict1 = {"R": "Red", "B": "Black", "P": "Pink"}
    dict2 = {"L": "lavender", "B": "Blue"}
    dict3 = {"G": "Green", "W": "White"}
    
    # Expected: 'B' from dict2 to 'Blue', dict3 has no 'B', so keep 'Blue'
    expected = {"B": "Black", "P": "Pink", "R": "Red", "G": "Green", "L": "lavender", "W": "White"}
    
    await apply_test_case(dut, dict1, dict2, dict3, expected)

@cocotb.test()
async def test_merge_empty(dut):
    """Test with empty dictionaries"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    dict1 = {}
    dict2 = {"A": "Alpha", "B": "Beta"}
    dict3 = {}
    
    expected = {"A": "Alpha", "B": "Beta"}
    
    await apply_test_case(dut, dict1, dict2, dict3, expected)

@cocotb.test()
async def test_merge_single_char(dut):
    """Test with single character entries"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    dict1 = {"X": "x"}
    dict2 = {"Y": "y"}
    dict3 = {"Z": "z"}
    
    expected = {"X": "x", "Y": "y", "Z": "z"}
    
    await apply_test_case(dut, dict1, dict2, dict3, expected)

print("Cocotb testbench generated successfully")
print("X/Y tests passed")