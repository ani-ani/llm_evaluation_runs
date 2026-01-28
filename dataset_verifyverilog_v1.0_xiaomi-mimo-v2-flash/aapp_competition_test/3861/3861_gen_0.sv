module max_non_square(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] arr_0,
    input wire signed [15:0] arr_1,
    input wire signed [15:0] arr_2,
    input wire signed [15:0] arr_3,
    input wire signed [15:0] arr_4,
    input wire signed [15:0] arr_5,
    input wire signed [15:0] arr_6,
    input wire signed [15:0] arr_7,
    input wire signed [15:0] arr_8,
    input wire signed [15:0] arr_9,
    input wire signed [15:0] arr_10,
    input wire signed [15:0] arr_11,
    input wire signed [15:0] arr_12,
    input wire signed [15:0] arr_13,
    input wire signed [15:0] arr_14,
    input wire signed [15:0] arr_15,
    output reg signed [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] LOAD     = 2'd1;
    localparam [1:0] CHECK_SQ = 2'd2;
    localparam [1:0] UPDATE   = 2'd3;

    // Binary search states
    localparam [1:0] BS_IDLE  = 2'd0;
    localparam [1:0] BS_CHECK = 2'd1;
    localparam [1:0] BS_DONE  = 2'd2;

    reg [1:0] main_state;
    reg [1:0] bs_state;
    reg [3:0] index;           // 0 to 15 for array elements
    reg signed [15:0] current_val;
    reg signed [15:0] best_val;
    
    // Binary search registers
    reg [7:0] low;             // 0 to 182
    reg [7:0] high;            // 0 to 182
    reg [7:0] mid;
    reg [15:0] mid_sq;         // mid * mid
    reg is_perfect_square;
    reg bs_done_flag;

    // Control flags
    reg processing;
    reg bs_start;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            main_state <= IDLE;
            bs_state <= BS_IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            best_val <= 16'sd0;
            current_val <= 16'sd0;
            index <= 4'd0;
            low <= 8'd0;
            high <= 8'd0;
            mid <= 8'd0;
            mid_sq <= 16'd0;
            is_perfect_square <= 1'b0;
            bs_done_flag <= 1'b0;
            processing <= 1'b0;
            bs_start <= 1'b0;
        end else begin
            done <= 1'b0;
            bs_start <= 1'b0;

            case (main_state)
                IDLE: begin
                    if (start) begin
                        main_state <= LOAD;
                        index <= 4'd0;
                        best_val <= 16'sd0;
                        processing <= 1'b1;
                    end
                end

                LOAD: begin
                    // Select current value based on index
                    case (index)
                        4'd0:  current_val <= arr_0;
                        4'd1:  current_val <= arr_1;
                        4'd2:  current_val <= arr_2;
                        4'd3:  current_val <= arr_3;
                        4'd4:  current_val <= arr_4;
                        4'd5:  current_val <= arr_5;
                        4'd6:  current_val <= arr_6;
                        4'd7:  current_val <= arr_7;
                        4'd8:  current_val <= arr_8;
                        4'd9:  current_val <= arr_9;
                        4'd10: current_val <= arr_10;
                        4'd11: current_val <= arr_11;
                        4'd12: current_val <= arr_12;
                        4'd13: current_val <= arr_13;
                        4'd14: current_val <= arr_14;
                        4'd15: current_val <= arr_15;
                        default: current_val <= 16'sd0;
                    endcase
                    main_state <= CHECK_SQ;
                    bs_start <= 1'b1;
                end

                CHECK_SQ: begin
                    if (bs_done_flag) begin
                        bs_done_flag <= 1'b0;
                        main_state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // If negative or not a perfect square, it's a candidate
                    if ((current_val < 16'sd0) || !is_perfect_square) begin
                        if (current_val > best_val) begin
                            best_val <= current_val;
                        end
                    end
                    
                    if (index == 4'd15) begin
                        // Last element processed
                        result <= best_val;
                        done <= 1'b1;
                        main_state <= IDLE;
                        processing <= 1'b0;
                    end else begin
                        index <= index + 4'd1;
                        main_state <= LOAD;
                    end
                end

                default: main_state <= IDLE;
            endcase

            // Binary Search FSM
            case (bs_state)
                BS_IDLE: begin
                    if (bs_start && processing) begin
                        // Check for negative values immediately
                        if (current_val < 16'sd0) begin
                            is_perfect_square <= 1'b0;
                            bs_done_flag <= 1'b1;
                            bs_state <= BS_IDLE;
                        end else begin
                            low <= 8'd0;
                            high <= 8'd182;  // ceil(sqrt(32767)) + 1
                            bs_state <= BS_CHECK;
                        end
                    end
                end

                BS_CHECK: begin
                    if (low > high) begin
                        // Search finished, check if exact match
                        if (mid_sq == current_val[15:0]) begin
                            is_perfect_square <= 1'b1;
                        end else begin
                            is_perfect_square <= 1'b0;
                        end
                        bs_done_flag <= 1'b1;
                        bs_state <= BS_IDLE;
                    end else begin
                        mid <= (low + high) >> 1;
                        // Calculate mid^2 using shift-add method
                        mid_sq <= mid * mid;
                        
                        // Compare in same cycle
                        if (mid_sq < current_val[15:0]) begin
                            low <= mid + 8'd1;
                        end else if (mid_sq > current_val[15:0]) begin
                            if (mid == 8'd0) begin
                                high <= mid;
                            end else begin
                                high <= mid - 8'd1;
                            end
                        end else begin
                            // Exact match found
                            low <= high + 8'd1; // Force exit condition
                            mid_sq <= mid * mid; // Keep the value
                        end
                        bs_state <= BS_CHECK;
                    end
                end

                default: bs_state <= BS_IDLE;
            endcase
        end
    end

endmodule