module partition_divider (
 input clk,
 input rst_n,
 input start,
 input [3:0] n,
 input [5:0] c,
 input [5:0] year [0:15],
 input [3:0] a [0:15],
 input [3:0] b [0:15],
 output reg [5:0] result_year,
 output reg result_valid,
 output reg result_impossible,
 output reg done
);

 // Default assignments
 assign result_year = 0;
 assign result_valid = 0;
 assign result_impossible = 1;
 assign done = 0;

 endmodule