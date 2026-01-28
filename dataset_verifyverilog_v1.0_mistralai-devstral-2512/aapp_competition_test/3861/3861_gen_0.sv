module max_non_square(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] arr_0,
    input signed [15:0] arr_1,
    input signed [15:0] arr_2,
    input signed [15:0] arr_3,
    input signed [15:0] arr_4,
    input signed [15:0] arr_5,
    input signed [15:0] arr_6,
    input signed [15:0] arr_7,
    input signed [15:0] arr_8,
    input signed [15:0] arr_9,
    input signed [15:0] arr_10,
    input signed [15:0] arr_11,
    input signed [15:0] arr_12,
    input signed [15:0] arr_13,
    input signed [15:0] arr_14,
    input signed [15:0] arr_15,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PROCESS_ARRAY = 4'd1;
    localparam [3:0] CHECK_SQUARE = 4'd2;
    localparam [3:0] FINISH = 4'd3;

    // Array index
    reg [3:0] arr_index;

    // Current element being processed
    reg signed [15:0] current_element;

    // Binary search variables
    reg [7:0] low;
    reg [7:0] high;
    reg [7:0] mid;
    reg signed [31:0] mid_squared;

    // Binary search state
    reg [0:0] bs_state; // 0: init, 1: search

    // Is perfect square flag
    reg is_perfect_square;

    // Best candidate
    reg signed [15:0] best_candidate;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Main FSM
    reg [3:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            arr_index <= 4'd0;
            current_element <= 16'd0;
            low <= 8'd0;
            high <= 8'd182;
            mid <= 8'd0;
            mid_squared <= 32'd0;
            bs_state <= 1'b0;
            is_perfect_square <= 1'b0;
            best_candidate <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS_ARRAY;
                        arr_index <= 4'd0;
                        best_candidate <= 16'd0;
                    end
                end

                PROCESS_ARRAY: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Select current element
                    case (arr_index)
                        4'd0: current_element <= arr_0;
                        4'd1: current_element <= arr_1;
                        4'd2: current_element <= arr_2;
                        4'd3: current_element <= arr_3;
                        4'd4: current_element <= arr_4;
                        4'd5: current_element <= arr_5;
                        4'd6: current_element <= arr_6;
                        4'd7: current_element <= arr_7;
                        4'd8: current_element <= arr_8;
                        4'd9: current_element <= arr_9;
                        4'd10: current_element <= arr_10;
                        4'd11: current_element <= arr_11;
                        4'd12: current_element <= arr_12;
                        4'd13: current_element <= arr_13;
                        4'd14: current_element <= arr_14;
                        4'd15: current_element <= arr_15;
                        default: current_element <= 16'd0;
                    endcase

                    // Initialize binary search
                    low <= 8'd0;
                    high <= 8'd182;
                    mid <= 8'd0;
                    mid_squared <= 32'd0;
                    bs_state <= 1'b0;
                    is_perfect_square <= 1'b0;
                    
                    // Check if negative (automatically non-square)
                    if (current_element[15]) begin
                        // Negative number - not a perfect square
                        if (best_candidate < current_element) begin
                            best_candidate <= current_element;
                        end
                        
                        // Move to next element
                        if (arr_index == 4'd15) begin
                            state <= FINISH;
                        end else begin
                            arr_index <= arr_index + 4'd1;
                        end
                    end else begin
                        // Non-negative - check if perfect square
                        state <= CHECK_SQUARE;
                    end
                end

                CHECK_SQUARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    case (bs_state)
                        1'b0: begin // Initialize
                            low <= 8'd0;
                            high <= 8'd182;
                            mid <= 8'd0;
                            mid_squared <= 32'd0;
                            bs_state <= 1'b1;
                        end
                        1'b1: begin // Binary search
                            if (low <= high) begin
                                mid <= (low + high) >> 1;
                                mid_squared <= $signed(mid) * $signed(mid);
                                
                                if (mid_squared == current_element) begin
                                    is_perfect_square <= 1'b1;
                                    bs_state <= 1'b0;
                                end else if (mid_squared < current_element) begin
                                    low <= mid + 8'd1;
                                end else begin
                                    high <= mid - 8'd1;
                                end
                            end else begin
                                // Binary search complete
                                bs_state <= 1'b0;
                                state <= PROCESS_ARRAY;
                                
                                // Update best candidate if not perfect square
                                if (!is_perfect_square && best_candidate < current_element) begin
                                    best_candidate <= current_element;
                                end
                                
                                // Move to next element
                                if (arr_index == 4'd15) begin
                                    state <= FINISH;
                                end else begin
                                    arr_index <= arr_index + 4'd1;
                                end
                            end
                        end
                    endcase
                end

                FINISH: begin
                    result <= best_candidate;
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