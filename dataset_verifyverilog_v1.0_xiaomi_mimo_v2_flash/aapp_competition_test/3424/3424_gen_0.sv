module find_base (
    input clk,
    input rst_n,
    input start,
    input [15:0] y,
    input [15:0] l,
    output reg [15:0] b,
    output reg done,
    output reg valid
);

// Parameters
localparam [15:0] MAX_B = 16'd256;
localparam [3:0] MAX_DIGITS = 4'd16;

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] START_SEARCH = 3'd1;
localparam [2:0] COMPUTE_DIGITS = 3'd2;
localparam [2:0] CHECK_DIGITS = 3'd3;
localparam [2:0] CHECK_VALUE = 3'd4;
localparam [2:0] UPDATE_B = 3'd5;
localparam [2:0] DONE = 3'd6;

// Internal registers
reg [2:0] state;
reg [15:0] current_b;
reg [31:0] temp_y;
reg [31:0] temp_b;
reg [15:0] digits [0:15];
reg [3:0] digit_count;
reg [3:0] digit_idx;
reg [15:0] base10_value;
reg found_valid;
reg [15:0] best_b;
reg [3:0] loop_counter;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        b <= 16'd0;
        done <= 1'b0;
        valid <= 1'b0;
        current_b <= 16'd0;
        best_b <= 16'd0;
        found_valid <= 1'b0;
        digit_count <= 4'd0;
        base10_value <= 16'd0;
        temp_y <= 32'd0;
        temp_b <= 32'd0;
        loop_counter <= 4'd0;
        digit_idx <= 4'd0;
        for (i = 0; i < 16; i = i + 1) begin
            digits[i] <= 16'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    state <= START_SEARCH;
                    found_valid <= 1'b0;
                    best_b <= 16'd0;
                    current_b <= (y < MAX_B) ? y : MAX_B;
                end
            end

            START_SEARCH: begin
                if (current_b < 16'd2) begin
                    state <= DONE;
                end else begin
                    temp_y <= {16'd0, y};
                    temp_b <= {16'd0, current_b};
                    digit_count <= 4'd0;
                    loop_counter <= 4'd0;
                    state <= COMPUTE_DIGITS;
                end
            end

            COMPUTE_DIGITS: begin
                if (temp_y == 32'd0 || loop_counter >= MAX_DIGITS) begin
                    state <= CHECK_DIGITS;
                    digit_idx <= 4'd0;
                end else begin
                    if (temp_y >= temp_b) begin
                        digits[digit_count] <= temp_y % temp_b;
                        temp_y <= temp_y / temp_b;
                        digit_count <= digit_count + 1'b1;
                    end else begin
                        digits[digit_count] <= temp_y[15:0];
                        digit_count <= digit_count + 1'b1;
                        temp_y <= 32'd0;
                    end
                    loop_counter <= loop_counter + 1'b1;
                end
            end

            CHECK_DIGITS: begin
                if (digit_idx >= digit_count) begin
                    state <= CHECK_VALUE;
                    digit_idx <= 4'd0;
                    base10_value <= 16'd0;
                end else if (digits[digit_idx] > 9) begin
                    state <= UPDATE_B;
                end else begin
                    digit_idx <= digit_idx + 1'b1;
                end
            end

            CHECK_VALUE: begin
                if (digit_idx >= digit_count) begin
                    if (base10_value >= l) begin
                        found_valid <= 1'b1;
                        best_b <= current_b;
                        state <= DONE;
                    end else begin
                        state <= UPDATE_B;
                    end
                end else begin
                    base10_value <= base10_value * 10 + digits[digit_idx];
                    digit_idx <= digit_idx + 1'b1;
                end
            end

            UPDATE_B: begin
                current_b <= current_b - 16'd1;
                state <= START_SEARCH;
            end

            DONE: begin
                done <= 1'b1;
                if (found_valid) begin
                    b <= best_b;
                    valid <= 1'b1;
                end else begin
                    b <= 16'd0;
                    valid <= 1'b0;
                end
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule