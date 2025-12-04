import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray, Range

@cocotb.test()
async def test_add_string(dut):
    test_cases = [
        # Test 1: Numbers with 'temp' prefix
        {
            'prefix': b'temp\\x00\\x00\\x00\\x00',
            'list': [b'1', b'2', b'3', b'4'],
            'expected': [b'temp1\\x00\\x00\\x00', b'temp2\\x00\\x00\\x00', b'temp3\\x00\\x00\\x00', b'temp4\\x00\\x00\\x00']
        },
        # Test 2: Letters with 'python' prefix
        {
            'prefix': b'python\\x00\\x00',
            'list': [b'a', b'b', b'c', b'd'],
            'expected': [b'pythona\\x00\\x00', b'pythonb\\x00\\x00', b'pythonc\\x00\\x00', b'pythond\\x00\\x00']
        },
        # Test 3: Numbers with 'string' prefix
        {
            'prefix': b'string\\x00\\x00',
            'list': [b'5', b'6', b'7', b'8'],
            'expected': [b'string5\\x00\\x00', b'string6\\x00\\x00', b'string7\\x00\\x00', b'string8\\x00\\x00']
        }
    ]

    passed = 0
    for idx, test in enumerate(test_cases):
        # Convert inputs to Verilog format
        prefix_val = int.from_bytes(test['prefix'], byteorder='big')
        dut.prefix_bytes.value = prefix_val
        
        for i in range(4):
            list_val = int.from_bytes(test['list'][i], byteorder='big')
            dut.list[i].value = list_val
        
        await Timer(1, units='ns')
        
        # Check outputs
        success = True
        for i in range(4):
            output_chunk = dut.formatted_strings.value[72*i:72*(i+1)]
            output_bytes = output_chunk.buff.to_bytes(9, 'big')
            expected_bytes = test['expected'][i]
            
            if output_bytes != expected_bytes:
                dut._log.error(f"Test {idx+1} elem {i} FAIL:"\
                              f" Got {output_bytes.hex()} vs expected {expected_bytes.hex()}")
                success = False
        
        if success:
            passed += 1
            dut._log.info(f"Test {idx+1} PASS")
        
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")