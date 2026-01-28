module special_filter(
    input clk,
    input rst_n,
    input start,
    input [2:0] len,
    input signed [7:0] arr [0:7],
    output reg [3:0] result,
    output reg done
);

    // Parameters
    localparam [2:0] MAX_ARRAY_SIZE = 3'd7;
    localparam [2:0] DATA_WIDTH = 3'd7;
    localparam [2:0] RESULT_WIDTH = 3'd3;

    // State declarations
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] ABS        = 4'd1;
    localparam [3:0] CHECK_GT10 = 4'd2;
    localparam [3:0] GET_LAST   = 4'd3;
    localparam [3:0] GET_FIRST  = 4'd4;
    localparam [3:0] CHECK_ODD  = 4'd5;
    localparam [3:0] INCREMENT  = 4'd6;
    localparam [3:0] NEXT       = 4'd7;
    localparam [3:0] DONE       = 4'd8;

    // Internal registers
    reg [3:0] state;
    reg [2:0] index;
    reg [7:0] abs_value;
    reg [3:0] last_digit;
    reg [3:0] first_digit;
    reg [7:0] temp_value;
    reg valid;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd120;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            abs_value <= 8'd0;
            last_digit <= 4'd0;
            first_digit <= 4'd0;
            temp_value <= 8'd0;
            valid <= 1'b0;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= ABS;
                        index <= 3'd0;
                        result <= 4'd0;
                    end
                end

                ABS: begin
                    // Compute absolute value
                    if (arr[index][7]) begin
                        abs_value <= ~arr[index] + 8'd1;
                    end else begin
                        abs_value <= arr[index];
                    end
                    state <= CHECK_GT10;
                end

                CHECK_GT10: begin
                    if (abs_value > 8'd10) begin
                        state <= GET_LAST;
                    end else begin
                        state <= NEXT;
                    end
                end

                GET_LAST: begin
                    // Extract last digit (abs_value % 10)
                    last_digit <= abs_value[3:0];
                    state <= GET_FIRST;
                end

                GET_FIRST: begin
                    // Extract first digit by repeated division
                    temp_value <= abs_value;
                    first_digit <= 4'd0;
                    state <= GET_FIRST;
                    if (temp_value >= 8'd10) begin
                        temp_value <= temp_value / 8'd10;
                    end else begin
                        first_digit <= temp_value[3:0];
                        state <= CHECK_ODD;
                    end
                end

                CHECK_ODD: begin
                    // Check if both digits are odd
                    valid <= (last_digit[0] & first_digit[0]);
                    state <= INCREMENT;
                end

                INCREMENT: begin
                    if (valid) begin
                        result <= result + 4'd1;
                    end
                    state <= NEXT;
                end

                NEXT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index == len) begin
                        state <= DONE;
                    end else begin
                        index <= index + 3'd1;
                        state <= ABS;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule