module average_operations (
    input clk,
    input rst_n,
    input start,
    input [7:0] pattern, // 4 positions, 2 bits each: pattern[1:0]=pos0, pattern[3:2]=pos1, pattern[5:4]=pos2, pattern[7:6]=pos3
    output reg [31:0] result,
    output reg done
);

// Encoding: 00 = T, 01 = H, 10 = ?, 11 = reserved (treated as ?)
// Precomputed distances for all 4-bit states (bit 0 = leftmost coin)
reg [7:0] dist_rom [0:15];
initial begin
    dist_rom[0]  = 8'd0;  // 0000
    dist_rom[1]  = 8'd1;  // 0001
    dist_rom[2]  = 8'd3;  // 0010
    dist_rom[3]  = 8'd2;  // 0011
    dist_rom[4]  = 8'd5;  // 0100
    dist_rom[5]  = 8'd4;  // 0101
    dist_rom[6]  = 8'd6;  // 0110
    dist_rom[7]  = 8'd3;  // 0111
    dist_rom[8]  = 8'd7;  // 1000
    dist_rom[9]  = 8'd6;  // 1001
    dist_rom[10] = 8'd8;  // 1010
    dist_rom[11] = 8'd5;  // 1011
    dist_rom[12] = 8'd10; // 1100
    dist_rom[13] = 8'd7;  // 1101
    dist_rom[14] = 8'd9;  // 1110
    dist_rom[15] = 8'd4;  // 1111
end

// Internal registers
reg [3:0] i;          // iteration counter (0..15)
reg [15:0] sum;       // sum of distances for matching states
reg [2:0] q;          // number of '?' in pattern
reg [1:0] state;      // state machine state
localparam [1:0] IDLE = 2'd0;
localparam [1:0] ITER = 2'd1;
localparam [1:0] COMPUTE = 2'd2;
localparam [1:0] DONE_STATE = 2'd3;

// Combinatorial: match detection for current i
reg match_reg;
integer j;
always @(*) begin
    match_reg = 1;
    for (j=0; j<4; j=j+1) begin
        case (pattern[2*j+1:2*j])
            2'b00: if (i[j] != 1'b0) match_reg = 0; // T requires 0
            2'b01: if (i[j] != 1'b1) match_reg = 0; // H requires 1
            default: ; // ? or reserved: no constraint
        endcase
    end
end

// Combinatorial: count number of '?' in pattern
always @(*) begin
    q = 0;
    for (j=0; j<4; j=j+1) begin
        if (pattern[2*j+1:2*j] == 2'b10) q = q + 1;
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        i <= 4'd0;
        sum <= 16'd0;
        result <= 32'd0;
        done <= 1'b0;
    end else begin
        done <= 1'b0;
        case (state)
            IDLE: begin
                if (start) begin
                    i <= 4'd0;
                    sum <= 16'd0;
                    state <= ITER;
                end
            end

            ITER: begin
                if (i < 4'd15) begin
                    // For current i, if match, add distance
                    if (match_reg) sum <= sum + dist_rom[i];
                    i <= i + 1;
                end else begin
                    // i == 15, process last iteration
                    if (match_reg) sum <= sum + dist_rom[i];
                    i <= i + 1; // becomes 16
                    state <= COMPUTE;
                end
            end

            COMPUTE: begin
                // Compute result = (sum << 16) >> q  (fixed-point Q16.16)
                // q is 0..4, so shift left by (16 - q)
                case (q)
                    3'd0: result <= sum << 16;
                    3'd1: result <= sum << 15;
                    3'd2: result <= sum << 14;
                    3'd3: result <= sum << 13;
                    3'd4: result <= sum << 12;
                    default: result <= 32'd0;
                endcase
                state <= DONE_STATE;
                done <= 1'b1;
            end

            DONE_STATE: begin
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule