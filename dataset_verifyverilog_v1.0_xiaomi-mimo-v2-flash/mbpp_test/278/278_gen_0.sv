module count_before_tuple (
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [15:0] arr_0,
    input [15:0] arr_1,
    input [15:0] arr_2,
    input [15:0] arr_3,
    input [15:0] arr_4,
    input [15:0] arr_5,
    input [15:0] arr_6,
    input [15:0] arr_7,
    input [15:0] arr_8,
    input [15:0] arr_9,
    input [15:0] arr_10,
    input [15:0] arr_11,
    input [15:0] arr_12,
    input [15:0] arr_13,
    input [15:0] arr_14,
    input [15:0] arr_15,
    output reg [3:0] result,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_LEN = 4'd15;
    localparam signed [15:0] TUPLE_VAL_A = 16'sd4;
    localparam signed [15:0] TUPLE_VAL_B = 16'sd6;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Registers
    reg [2:0] state;
    reg [3:0] idx;
    reg [3:0] result_reg;
    reg match_found;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    // Internal signals for array access
    reg signed [15:0] current_val;
    reg signed [15:0] next_val;

    always @(*) begin
        // Combinational array lookup
        case (idx)
            4'd0: current_val = arr_0;
            4'd1: current_val = arr_1;
            4'd2: current_val = arr_2;
            4'd3: current_val = arr_3;
            4'd4: current_val = arr_4;
            4'd5: current_val = arr_5;
            4'd6: current_val = arr_6;
            4'd7: current_val = arr_7;
            4'd8: current_val = arr_8;
            4'd9: current_val = arr_9;
            4'd10: current_val = arr_10;
            4'd11: current_val = arr_11;
            4'd12: current_val = arr_12;
            4'd13: current_val = arr_13;
            4'd14: current_val = arr_14;
            4'd15: current_val = arr_15;
            default: current_val = 16'sd0;
        endcase

        case (idx + 4'd1)
            4'd0: next_val = arr_0;
            4'd1: next_val = arr_1;
            4'd2: next_val = arr_2;
            4'd3: next_val = arr_3;
            4'd4: next_val = arr_4;
            4'd5: next_val = arr_5;
            4'd6: next_val = arr_6;
            4'd7: next_val = arr_7;
            4'd8: next_val = arr_8;
            4'd9: next_val = arr_9;
            4'd10: next_val = arr_10;
            4'd11: next_val = arr_11;
            4'd12: next_val = arr_12;
            4'd13: next_val = arr_13;
            4'd14: next_val = arr_14;
            4'd15: next_val = arr_15;
            default: next_val = 16'sd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            idx <= 4'd0;
            result_reg <= 4'd0;
            match_found <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 4'd0;
                    result_reg <= 4'd0;
                    match_found <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= SCAN;
                    end
                end

                SCAN: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if we are still within valid bounds
                    if (idx < len) begin
                        // Check if current value is TUPLE_VAL_A and next value matches TUPLE_VAL_B
                        if ((current_val == TUPLE_VAL_A) && ((idx + 4'd1) < len) && (next_val == TUPLE_VAL_B)) begin
                            match_found <= 1'b1;
                            result_reg <= idx;
                            state <= FINISH;
                        end else begin
                            // Continue scanning
                            idx <= idx + 4'd1;
                            // Update result as count of elements checked so far (excluding current if it's not a tuple)
                            // But the problem asks for count of elements BEFORE the first element of the tuple.
                            // If we don't find it at index i, we have checked i+1 elements.
                            // We will only update result if we reach the end.
                        end
                    end else begin
                        // End of array reached without finding tuple
                        result_reg <= len;
                        state <= FINISH;
                    end

                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= result_reg;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule