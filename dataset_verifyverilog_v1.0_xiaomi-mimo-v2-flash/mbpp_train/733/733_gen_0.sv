module binary_search_first(
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
    input wire [7:0] x,
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // FSM States
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] LOOP     = 3'd2;
    localparam [2:0] CHECK    = 3'd3;
    localparam [2:0] CHECK_LEFT = 3'd4;
    localparam [2:0] COMPLETE = 3'd5;
    localparam [2:0] DONE     = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] left, right, mid;
    reg [7:0] result_reg;
    reg [7:0] arr_mid_val;
    reg [7:0] next_result;
    reg [7:0] next_left, next_right;
    reg [7:0] next_mid;
    
    // Combinational logic for array access
    always @(*) begin
        case (mid[3:0])
            4'd0: arr_mid_val = arr_0;
            4'd1: arr_mid_val = arr_1;
            4'd2: arr_mid_val = arr_2;
            4'd3: arr_mid_val = arr_3;
            4'd4: arr_mid_val = arr_4;
            4'd5: arr_mid_val = arr_5;
            4'd6: arr_mid_val = arr_6;
            4'd7: arr_mid_val = arr_7;
            4'd8: arr_mid_val = arr_8;
            4'd9: arr_mid_val = arr_9;
            default: arr_mid_val = 8'd0;
        endcase
    end

    // Next state and register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            left <= 8'd0;
            right <= 8'd0;
            mid <= 8'd0;
            result_reg <= 8'd255;  // 0xFF for not found
            next_left <= 8'd0;
            next_right <= 8'd0;
            next_mid <= 8'd0;
            next_result <= 8'd255;
            result <= 8'd255;
            done <= 1'b0;
        end else begin
            state <= next_state;
            left <= next_left;
            right <= next_right;
            mid <= next_mid;
            result_reg <= next_result;
            
            case (state)
                IDLE: begin
                    result <= 8'd255;
                    done <= 1'b0;
                end
                COMPLETE: begin
                    result <= result_reg;
                    done <= 1'b1;
                end
                DONE: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // FSM Logic
    always @(*) begin
        next_state = state;
        next_left = left;
        next_right = right;
        next_mid = mid;
        next_result = result_reg;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_left = 8'd0;
                if (len == 4'd0) begin
                    next_right = 8'd0;
                end else begin
                    next_right = {4'd0, len} - 8'd1;
                end
                next_result = 8'd255;  // Initialize to not found
                next_state = LOOP;
            end

            LOOP: begin
                // mid = (left + right) >> 1
                next_mid = (left + right) >> 1;
                next_state = CHECK;
            end

            CHECK: begin
                // Check if left <= right
                if (left > right) begin
                    next_state = COMPLETE;
                end else begin
                    // Compare arr[mid] with x
                    if (arr_mid_val == x) begin
                        // Found match, record and search left
                        next_result = mid;
                        if (mid == 8'd0) begin
                            // Can't go left anymore
                            next_state = COMPLETE;
                        end else begin
                            next_right = mid - 8'd1;
                            next_state = CHECK_LEFT;
                        end
                    end else if (x < arr_mid_val) begin
                        // Search left
                        if (mid == 8'd0) begin
                            next_state = COMPLETE;
                        end else begin
                            next_right = mid - 8'd1;
                            next_state = LOOP;
                        end
                    end else begin
                        // x > arr[mid], search right
                        next_left = mid + 8'd1;
                        next_state = LOOP;
                    end
                end
            end

            CHECK_LEFT: begin
                // Continue searching left after finding match
                if (left > right) begin
                    next_state = COMPLETE;
                end else begin
                    next_mid = (left + right) >> 1;
                    next_state = CHECK;
                end
            end

            COMPLETE: begin
                next_state = DONE;
            end

            DONE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule