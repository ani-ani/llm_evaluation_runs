// Failed to parse code
```json
{"code": "module prime_length_checker(\n  input  [4:0] str_len,\n  output       is_prime\n);\n\n  assign is_prime = (str_len == 5'd2)  ||\n                    (str_len == 5'd3)  ||\n                    (str_len == 5'd5)  ||\n                    (str_len == 5'd7)  ||\n                    (str_len == 5'd11) ||\n                    (str_len == 5'd13);\n\nendmodule"}