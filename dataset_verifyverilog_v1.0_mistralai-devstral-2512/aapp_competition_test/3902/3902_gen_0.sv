module SuffixFinder(
    input clk,
    input rst_n,
    input start,
    input [7:0] s_ascii [0:15],
    input [3:0] s_len,
    output reg [4:0] result_count,
    output reg [31:0] result_suffixes [0:15],
    output reg [1:0] result_len [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // DP arrays
    reg [15:0] reach2;
    reg [15:0] reach3;

    // Result storage
    reg [31:0] suffix_hashes [0:15];
    reg [4:0] suffix_count;
    reg [31:0] temp_suffix;
    reg [1:0] temp_len;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] k;
    // ... (remaining code abbreviated for brevity)
endmodule