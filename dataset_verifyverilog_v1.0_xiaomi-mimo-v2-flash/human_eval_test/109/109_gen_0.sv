module SortableByRotation (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [7:0] arr_8,
    input wire [7:0] arr_9,
    input wire [7:0] arr_10,
    input wire [7:0] arr_11,
    input wire [7:0] arr_12,
    input wire [7:0] arr_13,
    input wire [7:0] arr_14,
    input wire [7:0] arr_15,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE          = 2'd0;
    localparam [1:0] FIND_MIN      = 2'd1;
    localparam [1:0] VERIFY_ORDER  = 2'd2;
    localparam [1:0] COMPLETE      = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [7:0] min_val;
    reg [3:0] min_idx;
    reg [3:0] current_idx;
    reg [3:0] counter;
    reg [7:0] temp_val;
    reg temp_result;
    reg [3:0] next_idx;

    // Combinational logic for array access
    reg [7:0] current_element;
    reg [7:0] next_element;

    always @(*) begin
        // Get current element
        case (current_idx)
            4'd0: current_element = arr_0;
            4'd1: current_element = arr_1;
            4'd2: current_element = arr_2;
            4'd3: current_element = arr_3;
            4'd4: current_element = arr_4;
            4'd5: current_element = arr_5;
            4'd6: current_element = arr_6;
            4'd7: current_element = arr_7;
            4'd8: current_element = arr_8;
            4'd9: current_element = arr_9;
            4'd10: current_element = arr_10;
            4'd11: current_element = arr_11;
            4'd12: current_element = arr_12;
            4'd13: current_element = arr_13;
            4'd14: current_element = arr_14;
            4'd15: current_element = arr_15;
            default: current_element = 8'd0;
        endcase

        // Get next element (circular)
        next_idx = (current_idx + 4'd1) % len;
        case (next_idx)
            4'd0: next_element = arr_0;
            4'd1: next_element = arr_1;
            4'd2: next_element = arr_2;
            4'd3: next_element = arr_3;
            4'd4: next_element = arr_4;
            4'd5: next_element = arr_5;
            4'd6: next_element = arr_6;
            4'd7: next_element = arr_7;
            4'd8: next_element = arr_8;
            4'd9: next_element = arr_9;
            4'd10: next_element = arr_10;
            4'd11: next_element = arr_11;
            4'd12: next_element = arr_12;
            4'd13: next_element = arr_13;
            4'd14: next_element = arr_14;
            4'd15: next_element = arr_15;
            default: next_element = 8'd0;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            min_val <= 8'd0;
            min_idx <= 4'd0;
            current_idx <= 4'd0;
            counter <= 4'd0;
            temp_val <= 8'd0;
            temp_result <= 1'b1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Handle edge cases: empty or single element
                        if (len == 4'd0 || len == 4'd1) begin
                            result <= 1'b1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            // Initialize FIND_MIN phase
                            min_val <= current_element;
                            min_idx <= 4'd0;
                            current_idx <= 4'd1;
                            counter <= 4'd1;
                            state <= FIND_MIN;
                        end
                    end
                end

                FIND_MIN: begin
                    // Find minimum element
                    if (counter < len) begin
                        if (current_element < min_val) begin
                            min_val <= current_element;
                            min_idx <= current_idx;
                        end
                        current_idx <= current_idx + 4'd1;
                        counter <= counter + 4'd1;
                    end else begin
                        // Done finding minimum, start verification
                        current_idx <= min_idx;
                        counter <= 4'd0;
                        temp_result <= 1'b1;
                        state <= VERIFY_ORDER;
                    end
                end

                VERIFY_ORDER: begin
                    // Verify non-decreasing order circularly
                    if (counter < len) begin
                        // Check if current element > next element (violation)
                        if (current_element > next_element) begin
                            temp_result <= 1'b0;
                        end
                        current_idx <= next_idx;
                        counter <= counter + 4'd1;
                    end else begin
                        // Verification complete
                        result <= temp_result;
                        done <= 1'b1;
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule