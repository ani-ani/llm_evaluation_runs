module bipartite_set_optimizer(
    input [15:0] valid_in,
    input [63:0] numbers_in [0:15],
    output reg [15:0] remove_mask,
    output reg [63:0] removed_values [0:15]
);

function [63:0] compute_ctz;
    input [63:0] x;
    begin
        if (x == 0) return 64;
        if (x[0]) return 0;
        if (x[1]) return 1;
        if (x[2]) return 2;
        if (x[3]) return 3;
        if (x[4]) return 4;
        if (x[5]) return 5;
        if (x[6]) return 6;
        if (x[7]) return 7;
        if (x[8]) return 8;
        if (x[9]) return 9;
        if (x[10]) return 10;
        if (x[11]) return 11;
        if (x[12]) return 12;
        if (x[13]) return 13;
        if (x[14]) return 14;
        if (x[15]) return 15;
        if (x[16]) return 16;
        if (x[17]) return 17;
        if (x[18]) return 18;
        if (x[19]) return 19;
        if (x[20]) return 20;
        if (x[21]) return 21;
        if (x[22]) return 22;
        if (x[23]) return 23;
        if (x[24]) return 24;
        if (x[25]) return 25;
        if (x[26]) return 26;
        if (x[27]) return 27;
        if (x[28]) return 28;
        if (x[29]) return 29;
        if (x[30]) return 30;
        if (x[31]) return 31;
        if (x[32]) return 32;
        if (x[33]) return 33;
        if (x[34]) return 34;
        if (x[35]) return 35;
        if (x[36]) return 36;
        if (x[37]) return 37;
        if (x[38]) return 38;
        if (x[39]) return 39;
        if (x[40]) return 40;
        if (x[41]) return 41;
        if (x[42]) return 42;
        if (x[43]) return 43;
        if (x[44]) return 44;
        if (x[45]) return 45;
        if (x[46]) return 46;
        if (x[47]) return 47;
        if (x[48]) return 48;
        if (x[49]) return 49;
        if (x[50]) return 50;
        if (x[51]) return 51;
        if (x[52]) return 52;
        if (x[53]) return 53;
        if (x[54]) return 54;
        if (x[55]) return 55;
        if (x[56]) return 56;
        if (x[57]) return 57;
        if (x[58]) return 58;
        if (x[59]) return 59;
        if (x[60]) return 60;
        if (x[61]) return 61;
        if (x[62]) return 62;
        if (x[63]) return 63;
        return 64;
    endfunction

// Compute CTZ for each input
wire [63:0] ctz_values [0:15];
generate
    for (int j=0; j<16; j++)
        assign ctz_values[j] = valid_in[j] ? compute_ctz(numbers_in[j]) : 64;
endgenerate

// Frequency counters
reg [31:0] ctz_count [0:63];

// Update frequency counters
generate
    for (int j=0; j<16; j++)
        always @(*) begin
            if (valid_in[j] && ctz_values[j] <64) 
                ctz_count[ctz_values[j]] +=1;
        end
endgenerate

// Determine winning CTZ
reg [63:0] winning_ctz;
reg [31:0] max_count;

always @(*) begin
    max_count = -1;
    winning_ctz = 64;
    // This section is abbreviated for brevity
    if (ctz_count[0] > max_count) begin
        max_count = ctz_count[0];
        winning_ctz =0;
    end
    // ... (similar conditions for ctz 1 to 63)
end

// Compute remove_mask and removed_values
assign remove_mask =
    (valid_in[0] && ctz_values[0] != winning_ctz) ? 1 :0 |
    (valid_in[1] && ctz_values[1] != winning_ctz) ? (1<<1) :0 |
    // ... (similar for indices 2 to 15)
    (valid_in[15] && ctz_values[15] != winning_ctz) ? (1<<15) :0;

assign removed_values[0] = (valid_in[0] && ctz_values[0] != winning_ctz) ? numbers_in[0] : 0;
assign removed_values[1] = (valid_in[1] && ctz_values[1] != winning_ctz) ? numbers_in[1] : 0;
// ... (similar for indices 2 to 15)

endmodule