import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_clock_fixer(dut):
    """Test the clock fixer module with various inputs"""
    
    # Helper function to convert string time "17:30" to packed ASCII digits
    def pack_time(time_str):
        # time_str is like "17:30"
        # We only want digits: 1, 7, 3, 0
        digits = [ord(c) for c in time_str if c.isdigit()]
        if len(digits) == 4:
            return (digits[0] << 24) | (digits[1] << 16) | (digits[2] << 8) | digits[3]
        return 0

    def pack_format(fmt):
        return 1 if fmt == 12 else 2

    # Test cases: (format, input_time, expected_time)
    test_cases = [
        (24, "17:30", "17:30"),
        (12, "17:30", "07:30"),
        (24, "99:99", "09:09"),
        (12, "05:54", "05:54"),
        (12, "00:05", "01:05"),
        (24, "23:80", "23:00"),
        (24, "73:16", "03:16"),
        (12, "03:77", "03:07"),
        (12, "47:83", "07:03"),
        (24, "23:88", "23:08"),
        (24, "51:67", "01:07"),
        (12, "10:33", "10:33"),
        (12, "00:01", "01:01"),
        (12, "07:74", "07:04"),
        (12, "00:60", "01:00"),
        (24, "08:32", "08:32"),
        (24, "42:59", "02:59"),
        (24, "19:87", "19:07"),
        (24, "26:98", "06:08"),
        (12, "12:91", "12:01"),
        (12, "11:30", "11:30"),
        (12, "90:32", "10:32"),
        (12, "03:69", "03:09"),
        (12, "33:83", "03:03"),
        (24, "10:45", "10:45"),
        (24, "65:12", "05:12"),
        (24, "22:64", "22:04"),
        (24, "48:91", "08:01"),
        (12, "02:51", "02:51"),
        (12, "40:11", "10:11"),
        (12, "02:86", "02:06"),
        (12, "99:96", "09:06"),
        (24, "19:24", "19:24"),
        (24, "55:49", "05:49"),
        (24, "01:97", "01:07"),
        (24, "39:68", "09:08"),
        (24, "24:00", "04:00"),
        (12, "91:00", "01:00"),
        (24, "00:30", "00:30"),
        (12, "13:20", "03:20"),
        (12, "13:00", "03:00"),
        (12, "42:35", "02:35"),
        (12, "20:00", "10:00"),
        (12, "21:00", "01:00"),
        (24, "10:10", "10:10"),
        (24, "30:40", "00:40"),
        (24, "12:00", "12:00"),
        (12, "10:60", "10:00"),
        (24, "30:00", "00:00"),
        (24, "34:00", "04:00"),
        (12, "22:00", "02:00"),
        (12, "20:20", "10:20"),
    ]

    passed = 0
    total = len(test_cases)

    for fmt, in_time, exp_time in test_cases:
        dut.format.value = pack_format(fmt)
        dut.display_time.value = pack_time(in_time)
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        result_val = dut.corrected_time.value
        
        # Unpack result
        d0 = (result_val >> 24) & 0xFF
        d1 = (result_val >> 16) & 0xFF
        d2 = (result_val >> 8) & 0xFF
        d3 = result_val & 0xFF
        result_str = f"{chr(d0)}{chr(d1)}:{chr(d2)}{chr(d3)}"
        
        if result_str == exp_time:
            passed += 1
        else:
            print(f"Test failed for format={fmt}, input={in_time}: Expected {exp_time}, got {result_str}")

    print(f"
SUMMARY: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")

