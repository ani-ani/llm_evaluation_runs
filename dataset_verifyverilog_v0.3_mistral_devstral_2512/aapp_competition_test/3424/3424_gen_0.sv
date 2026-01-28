module find_base(
    input clk,
    input rst_n,
    input start,
    input [15:0] y,
    input [15:0] l,
    output reg [15:0] b,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [15:0] current_b;
    reg [15:0] digits [0:15];
    reg [3:0] digit_count;
    reg [15:0] base10_value;
    reg [15:0] best_b;
    reg found_valid;
    reg [3:0] digit_idx;
    reg [3:0] loop_counter;
    reg [31:0] temp_y;
    reg [31:0] temp_b;

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
            digit_idx <= 4'd0;
            loop_counter <= 4'd0;
            temp_y <= 32'd0;
            temp_b <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        found_valid <= 1'b0;
                        best_b <= 16'd0;
                        current_b <= (y < 16'd256) ? y : 16'd256;
                    end
                end

                COMPUTE: begin
                    if (current_b < 16'd2) begin
                        state <= DONE_STATE;
                    end else begin
                        temp_y <= {16'd0, y};
                        temp_b <= {16'd0, current_b};
                        digit_count <= 4'd0;
                        loop_counter <= 4'd0;
                        digit_idx <= 4'd0;
                        base10_value <= 16'd0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (digit_idx < digit_count) begin
                        if (digits[digit_idx] > 9) begin
                            current_b <= current_b - 16'd1;
                            state <= COMPUTE;
                        end else begin
                            digit_idx <= digit_idx + 4'd1;
                        end
                    end else begin
                        if (base10_value >= l) begin
                            found_valid <= 1'b1;
                            best_b <= current_b;
                        end
                        current_b <= current_b - 16'd1;
                        state <= COMPUTE;
                    end
                end

                DONE_STATE: begin
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

    // Compute digits and base10_value
    always @(posedge clk) begin
        if (state == COMPUTE && loop_counter < 4'd15) begin
            if (temp_y >= temp_b) begin
                digits[digit_count] <= temp_y[15:0] % temp_b[15:0];
                temp_y <= temp_y / temp_b;
                digit_count <= digit_count + 4'd1;
            end else begin
                digits[digit_count] <= temp_y[15:0];
                digit_count <= digit_count + 4'd1;
                temp_y <= 32'd0;
            end
            loop_counter <= loop_counter + 4'd1;
        end
    end

    // Compute base10_value
    always @(posedge clk) begin
        if (state == CHECK && digit_idx < digit_count) begin
            base10_value <= base10_value * 10 + digits[digit_idx];
        end
    end

endmodule