import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
TOPPING_BITS = 8
MAX_TOPPINGS = 256
MAX_FRIENDS = 10000
MAX_WISHES = 30
CLK_NS = 10
MAX_CYCLES = 10000

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
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
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'valid'):
        dut.valid.value = 0
    if has_signal(dut, 'done'):
        pass
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Parse input and generate data packets for DUT
def parse_and_generate_data(input_str):
    lines = input_str.strip().split('\n')
    n = int(lines[0])
    data_packets = []
    topping_to_idx = {}
    idx_counter = 0
    
    for i in range(1, n + 1):
        parts = lines[i].split()
        w = int(parts[0])
        # New friend packet: data_type=0, topping_idx=w, want=0
        data_packets.append((0, w, 0))
        
        for j in range(1, len(parts)):
            wish = parts[j]
            want = 1 if wish[0] == '+' else 0
            topping = wish[1:]
            if topping not in topping_to_idx:
                topping_to_idx[topping] = idx_counter
                idx_counter += 1
            idx = topping_to_idx[topping]
            # Wish packet: data_type=1, topping_idx=idx, want=want
            data_packets.append((1, idx, want))
    
    return data_packets, topping_to_idx

async def drive_data(dut, data_packets):
    for packet in data_packets:
        await RisingEdge(dut.clk)
        dut.valid.value = 1
        dut.data_type.value = packet[0]
        dut.topping_idx.value = clamp_to_width(packet[1], TOPPING_BITS)
        dut.want.value = packet[2]
        await RisingEdge(dut.clk)
        dut.valid.value = 0
        # Small gap between packets
        await Timer(1, units='ns')

@cocotb.test(timeout_time=10, timeout_unit='s')
async def test_pizza_selection(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_inputs = [
        "1\n4 +zucchini +mozzarella +mushrooms -artichoke\n",
        "3\n3 +redbeans +soylentgreen -bluecheese\n3 +redbeans -soylentgreen +bluecheese\n3 -redbeans +soylentgreen +bluecheese\n"
    ]
    
    expected_toppings_list = [
        ["zucchini", "mozzarella", "mushrooms", "artichoke"],
        ["redbeans", "soylentgreen", "bluecheese"]
    ]
    
    for test_idx, input_str in enumerate(test_inputs):
        cocotb.log.info(f"Running test case {test_idx + 1}")
        
        # Parse and generate data packets
        data_packets, topping_map = parse_and_generate_data(input_str)
        topping_list = list(topping_map.keys())
        topping_list.sort(key=lambda x: topping_map[x])
        
        # Start the module
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Drive data
        await drive_data(dut, data_packets)
        
        # Wait for done
        if has_signal(dut, 'done'):
            await wait_for_done(dut)
        else:
            await Timer(5000, units='ns')
        
        # Read result bitmask
        if has_signal(dut, 'result'):
            result_val = int(dut.result.value)
        else:
            raise TestFailure("Result signal not found")
        
        # Check that all expected toppings are selected
        expected_toppings = expected_toppings_list[test_idx]
        for topping in expected_toppings:
            if topping not in topping_map:
                raise TestFailure(f"Test {test_idx+1}: Expected topping '{topping}' not found in map")
            idx = topping_map[topping]
            bit = (result_val >> idx) & 1
            if bit != 1:
                raise TestFailure(f"Test {test_idx+1}: Topping '{topping}' (index {idx}) not selected, bitmask: {bin(result_val)}")
        
        # Optionally, verify satisfaction condition
        # For test case 1: 1 friend, 4 wishes, need >1/3 (i.e., >1.33) so at least 2 satisfied
        # For test case 2: 3 friends, each 3 wishes, need >1 (i.e., at least 2 satisfied per friend)
        # With all toppings selected, let's verify:
        # In test 1: +zucchini, +mozzarella, +mushrooms, -artichoke
        # All toppings selected => zucchini, mozzarella, mushrooms selected, artichoke selected
        # +zucchini satisfied, +mozzarella satisfied, +mushrooms satisfied, -artichoke NOT satisfied (since artichoke selected)
        # So 3/4 = 0.75 > 1/3, OK.
        # In test 2: All toppings selected
        # Friend1: +redbeans (yes), +soylentgreen (yes), -bluecheese (no) => 2/3 > 1/3
        # Friend2: +redbeans (yes), -soylentgreen (no), +bluecheese (yes) => 2/3
        # Friend3: -redbeans (no), +soylentgreen (yes), +bluecheese (yes) => 2/3
        # All OK.
        
        cocotb.log.info(f"Test case {test_idx + 1} passed. Result mask: {hex(result_val)}")
