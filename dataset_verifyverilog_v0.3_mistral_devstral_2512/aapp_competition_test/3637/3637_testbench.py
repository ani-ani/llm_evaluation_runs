import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pizza_solver(dut):
    # Start clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        {
            "num_friends": 1,
            "num_toppings": 4,
            "toppings": ["zucchini", "mozzarella", "mushrooms", "artichoke"],
            "friends": [
                [
                    ("+", "zucchini"),
                    ("+", "mozzarella"),
                    ("+", "mushrooms"),
                    ("-", "artichoke")
                ]
            ]
        },
        {
            "num_friends": 3,
            "num_toppings": 3,
            "toppings": ["redbeans", "soylentgreen", "bluecheese"],
            "friends": [
                [("+", "redbeans"), ("+", "soylentgreen"), ("-", "bluecheese")],
                [("+", "redbeans"), ("-", "soylentgreen"), ("+", "bluecheese")],
                [("-", "redbeans"), ("+", "soylentgreen"), ("+", "bluecheese")]
            ]
        }
    ]
    
    for tc in test_cases:
        # Map toppings to indices
        topping_to_idx = {name: idx for idx, name in enumerate(tc["toppings"])}
        
        # Pack wishes
        wishes_packed = 0
        wishes_count_packed = 0
        for f_idx, friend_wishes in enumerate(tc["friends"]):
            count = len(friend_wishes)
            wishes_count_packed |= (count & 0x7) << (3 * f_idx)
            for w_idx, (sign_str, topping) in enumerate(friend_wishes):
                topping_idx = topping_to_idx[topping]
                sign = 1 if sign_str == '+' else 0
                # valid bit is 1
                wish_bits = (topping_idx & 0x7) | (sign << 3) | (1 << 4)
                offset = (f_idx * 8 + w_idx) * 5
                wishes_packed |= wish_bits << offset
        
        # Assign to DUT
        if has_signal(dut, 'num_friends'):
            dut.num_friends.value = tc["num_friends"]
        if has_signal(dut, 'num_toppings'):
            dut.num_toppings.value = tc["num_toppings"]
        if has_signal(dut, 'wishes_packed'):
            dut.wishes_packed.value = wishes_packed
        if has_signal(dut, 'wishes_count_packed'):
            dut.wishes_count_packed.value = wishes_count_packed
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        # Read subset
        if not is_value_defined(dut.subset.value):
            raise TestFailure("Subset output is undefined")
        subset_val = int(dut.subset.value)
        
        # Verify condition
        all_ok = True
        for f_idx, friend_wishes in enumerate(tc["friends"]):
            total_wishes = len(friend_wishes)
            satisfied = 0
            for (sign_str, topping) in friend_wishes:
                topping_idx = topping_to_idx[topping]
                included = (subset_val >> topping_idx) & 1
                if sign_str == '+' and included:
                    satisfied += 1
                if sign_str == '-' and not included:
                    satisfied += 1
            # Check: satisfied > total_wishes/3
            if satisfied * 3 <= total_wishes:
                all_ok = False
                cocotb.log.error(f"Friend {f_idx} not satisfied: satisfied={satisfied}, total={total_wishes}")
        
        if all_ok:
            cocotb.log.info(f"Test case passed: subset={subset_val:08b}")
        else:
            raise TestFailure(f"Test case failed: subset={subset_val:08b}")
