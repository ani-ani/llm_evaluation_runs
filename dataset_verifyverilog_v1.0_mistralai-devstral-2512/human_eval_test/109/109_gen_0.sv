module can_sort_by_rotation(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [7:0] arr_8,
    input [7:0] arr_9,
    input [7:0] arr_10,
    input [7:0] arr_11,
    input [7:0] arr_12,
    input [7:0] arr_13,
    input [7:0] arr_14,
    input [7:0] arr_15,
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] FIND_MIN = 2'd1;
    localparam [1:0] VERIFY_ORDER = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [7:0] min_val;
    reg [3:0] min_idx;
    reg [3:0] current_idx;
    reg [3:0] counter;
    reg [7:0] temp_val;
    reg [7:0] next_val;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd100;

    // Array access helper
    always @(*) begin
        case (current_idx)
            4'd0: temp_val = arr_0;
            4'd1: temp_val = arr_1;
            4'd2: temp_val = arr_2;
            4'd3: temp_val = arr_3;
            4'd4: temp_val = arr_4;
            4'd5: temp_val = arr_5;
            4'd6: temp_val = arr_6;
            4'd7: temp_val = arr_7;
            4'd8: temp_val = arr_8;
            4'd9: temp_val = arr_9;
            4'd10: temp_val = arr_10;
            4'd11: temp_val = arr_11;
            4'd12: temp_val = arr_12;
            4'd13: temp_val = arr_13;
            4'd14: temp_val = arr_14;
            4'd15: temp_val = arr_15;
            default: temp_val = 8'd0;
        endcase
    end

    // Next element access helper
    always @(*) begin
        case ((current_idx + 4'd1) % len)
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
            default: next_val = 8'd0;
        endcase
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            min_val <= 8'd0;
            min_idx <= 4'd0;
            current_idx <= 4'd0;
            counter <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= FIND_MIN;
                        min_val <= 8'd255;
                        min_idx <= 4'd0;
                        counter <= 4'd0;
                    end
                end

                FIND_MIN: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Compare current element with min_val
                    case (counter)
                        4'd0: temp_val = arr_0;
                        4'd1: temp_val = arr_1;
                        4'd2: temp_val = arr_2;
                        4'd3: temp_val = arr_3;
                        4'd4: temp_val = arr_4;
                        4'd5: temp_val = arr_5;
                        4'd6: temp_val = arr_6;
                        4'd7: temp_val = arr_7;
                        4'd8: temp_val = arr_8;
                        4'd9: temp_val = arr_9;
                        4'd10: temp_val = arr_10;
                        4'd11: temp_val = arr_11;
                        4'd12: temp_val = arr_12;
                        4'd13: temp_val = arr_13;
                        4'd14: temp_val = arr_14;
                        4'd15: temp_val = arr_15;
                        default: temp_val = 8'd0;
                    endcase

                    if (temp_val < min_val) begin
                        min_val <= temp_val;
                        min_idx <= counter;
                    end

                    // Move to next element or finish
                    if (counter == len - 4'd1) begin
                        state <= VERIFY_ORDER;
                        current_idx <= min_idx;
                        counter <= 4'd0;
                        result <= 1'b1;  // Assume true until proven false
                    end else begin
                        counter <= counter + 4'd1;
                    end
                end

                VERIFY_ORDER: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if current element <= next element
                    if (temp_val > next_val) begin
                        result <= 1'b0;
                    end

                    // Move to next element
                    if (counter == len - 4'd1) begin
                        state <= COMPLETE;
                    end else begin
                        counter <= counter + 4'd1;
                        current_idx <= (current_idx + 4'd1) % len;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

endmodule