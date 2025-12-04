import cocotb
from cocotb.triggers import Timer

# ASCII mappings
key_map = {'R': ord('R'), 'B': ord('B'), 'P': ord('P'), 'G': ord('G'), 'W': ord('W'), 'O': ord('O'), 'L': ord('L')}
val_map = {'Black':1, 'Red':2, 'Pink':3, 'White':4, 'Green':5, 'Orange':6, 'Blue':7, 'lavender':8, 'Lavender':8}

def prepare_input(d):
    keys = [0]*3
    vals = [0]*3
    valid = [0]*3
    for i, (k, v) in enumerate(d.items()):
        if i >= 3: break  # max 3 entries per dict
        keys[i] = key_map[k]
        vals[i] = val_map[v]
        valid[i] = 1
    return (keys, vals, valid)

@cocotb.test()
async def test_dict_merger(dut):
    # Convert test cases to hardware representation
    test1_in = [
        prepare_input({"R":"Red", "B":"Black", "P":"Pink"}),
        prepare_input({"G":"Green", "W":"White"}),
        prepare_input({"O":"Orange", "W":"White", "B":"Black"})
    ]
    test1_out = {'B':1, 'R':2, 'P':3, 'G':5, 'W':4, 'O':6}

    test2_in = [
        prepare_input({"R":"Red", "B":"Black", "P":"Pink"}),
        prepare_input({"G":"Green", "W":"White"}),
        prepare_input({"L":"lavender", "B":"Blue"})
    ]
    test2_out = {'W':4, 'P':3, 'B':1, 'R':2, 'G':5, 'L':8}

    test3_in = [
        prepare_input({"R":"Red", "B":"Black", "P":"Pink"}),
        prepare_input({"L":"lavender", "B":"Blue"}),
        prepare_input({"G":"Green", "W":"White"})
    ]
    test3_out = {'B':1, 'P':3, 'R':2, 'G':5, 'L':8, 'W':4}

    tests = [(test1_in, test1_out), (test2_in, test2_out), (test3_in, test3_out)]
    passed = 0

    for inputs, expected in tests:
        # Apply inputs
        for dict_idx in range(3):
            keys, vals, valids = inputs[dict_idx]
            for i in range(3):
                getattr(dut, f"key_in{dict_idx+1}").value[i*8+7:i*8] = keys[i]
                getattr(dut, f"val_in{dict_idx+1}").value[i*4+3:i*4] = vals[i]
                getattr(dut, f"valid{dict_idx+1}").value[i] = valids[i]

        await Timer(1, units='ns')

        # Verify output
        all_match = True
        output = {}
        for i in range(8):
            if dut.merged_valid.value[i]:
                key = dut.merged_keys.value[i*8+7:i*8].integer
                val = dut.merged_vals.value[i*4+3:i*4].integer
                output[chr(key)] = val
        
        # Check expected results        
        for k, expected_val in expected.items():
            if output.get(k, 0) != expected_val:
                all_match = False
                dut._log.error(f"Key {k}: Got {output.get(k,'missing')}, expected {expected_val}")
        
        if all_match and len(output) == len(expected):
            passed += 1
            dut._log.info(f"PASS: {expected}")
        else:
            dut._log.error(f"FAIL: Got {output}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(tests)} tests passed")