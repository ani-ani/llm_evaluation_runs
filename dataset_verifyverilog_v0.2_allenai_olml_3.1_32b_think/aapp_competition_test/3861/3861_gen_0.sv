module max_non_square (
    input clk,
    input rst_n,
    input start,
    input [9:0] count_in,
    input valid_in,
    input [31:0] data_in,
    output reg [31:0] max_out,
    output reg done
);

// Parameters and states
parameter IDLE = 2'd0;
parameter PROCESSING = 2'd1;
parameter DONE = 2'd2;

reg [2:0] state;
reg [9:0] target_count, current_count;
reg [31:0] max_out;

// Extract 16-bit number
wire signed [15:0] num;
assign num = data_in[15:0];

// Binary search parameters for square check
localparam INIT_LOW = 1;
localparam INIT_HIGH = 200;
localparam NUM_STEPS = 8;

// Wires for each step of binary search
wire [15:0] low_1, high_1, mid_1, sq_1;
wire [15:0] low_2, high_2, mid_2, sq_2;
wire [15:0] low_3, high_3, mid_3, sq_3;
wire [15:0] low_4, high_4, mid_4, sq_4;
wire [15:0] low_5, high_5, mid_5, sq_5;
wire [15:0] low_6, high_6, mid_6, sq_6;
wire [15:0] low_7, high_7, mid_7, sq_7;
wire [15:0] low_8, high_8, mid_8, sq_8;

// Compute mid and square for each step
assign mid_1 = (INIT_LOW + INIT_HIGH) >> 1;
assign sq_1 = mid_1 * mid_1;
assign low_1 = (sq_1 < num) ? (mid_1 + 1) : INIT_LOW;
assign high_1 = (sq_1 < num) ? INIT_HIGH : (mid_1 - 1);

assign mid_2 = (low_1 + high_1) >> 1;
assign sq_2 = mid_2 * mid_2;
assign low_2 = (sq_2 < num) ? (mid_2 + 1) : low_1;
assign high_2 = (sq_2 < num) ? high_1 : (mid_2 - 1);

assign mid_3 = (low_2 + high_2) >> 1;
assign sq_3 = mid_3 * mid_3;
assign low_3 = (sq_3 < num) ? (mid_3 + 1) : low_2;
assign high_3 = (sq_3 < num) ? high_2 : (mid_3 - 1);

assign mid_4 = (low_3 + high_3) >> 1;
assign sq_4 = mid_4 * mid_4;
assign low_4 = (sq_4 < num) ? (mid_4 + 1) : low_3;
assign high_4 = (sq_4 < num) ? high_3 : (mid_4 - 1);

assign mid_5 = (low_4 + high_4) >> 1;
assign sq_5 = mid_5 * mid_5;
assign low_5 = (sq_5 < num) ? (mid_5 + 1) : low_4;
assign high_5 = (sq_5 < num) ? high_4 : (mid_5 - 1);

assign mid_6 = (low_5 + high_5) >> 1;
assign sq_6 = mid_6 * mid_6;
assign low_6 = (sq_6 < num) ? (mid_6 + 1) : low_5;
assign high_6 = (sq_6 < num) ? high_5 : (mid_6 - 1);

assign mid_7 = (low_6 + high_6) >> 1;
assign sq_7 = mid_7 * mid_7;
assign low_7 = (sq_7 < num) ? (mid_7 + 1) : low_6;
assign high_7 = (sq_7 < num) ? high_6 : (mid_7 - 1);

assign mid_8 = (low_7 + high_7) >> 1;
assign sq_8 = mid_8 * mid_8;
assign low_8 = (sq_8 < num) ? (mid_8 + 1) : low_7;
assign high_8 = (sq_8 < num) ? high_7 : (mid_8 - 1);

// Determine if it's a perfect square
assign is_square = (sq_1 == num) || (sq_2 == num) || (sq_3 == num) || (sq_4 == num) || (sq_5 == num) || (sq_6 == num) || (sq_7 == num) || (sq_8 == num);

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        target_count <= 0;
        current_count <= 0;
        max_out <= -32'd2147483648;
        done <= 0;
    end else begin
        if (start) begin
            max_out <= -32'd2147483648;
            done <= 0;
            target_count <= count_in;
            current_count <= target_count;
            state <= PROCESSING;
        end else begin
            if (state == IDLE) begin
                // Do nothing
            end else if (state == PROCESSING) begin
                if (valid_in) begin
                    if (num >= 0) begin
                        if (!is_square) begin
                            if (num > max_out) max_out <= num;
                        end
                    end else begin
                        if (num > max_out) max_out <= num;
                    end
                    current_count <= current_count - 1;
                    if (current_count == 0) begin
                        done <= 1;
                        state <= DONE;
                    end
                end
            end else if (state == DONE) begin
                // Do nothing
            end
        end
    end
end

endmodule