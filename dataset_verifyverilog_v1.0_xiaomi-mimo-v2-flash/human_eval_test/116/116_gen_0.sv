module sort_array_by_popcount(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LATCH   = 3'd1;
    localparam [2:0] COUNT   = 3'd2;
    localparam [2:0] SORT    = 3'd3;
    localparam [2:0] OUTPUT  = 3'd4;
    localparam [2:0] FINISH  = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] data [0:7];           // Latched input array
    reg [7:0] sorted_data [0:7];    // Working array for sorting
    reg [3:0] popcount [0:7];       // Popcount for each element (0-8)
    reg [3:0] cnt_idx;              // Index for counting bits
    reg [2:0] idx_i;                // Outer sort loop index
    reg [2:0] idx_j;                // Inner sort loop index
    reg [3:0] cycle_count;          // Safety counter (max 16)
    reg [3:0] passes;               // Bubble sort pass counter (max 8)
    reg [7:0] temp_val;             // Temporary swap value
    reg [3:0] temp_pop;             // Temporary popcount for swap

    // Combinational comparator logic
    wire comp_a_greater_b;
    wire pop_a_gt_pop_b;
    wire pop_a_eq_pop_b;
    wire val_a_gt_val_b;

    // Popcount calculation (combinational)
    function automatic [3:0] calc_popcount(input [7:0] byte_val);
        integer i;
        reg [3:0] count;
        begin
            count = 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                count = count + byte_val[i];
            end
            calc_popcount = count;
        end
    endfunction

    // Comparator: Compare (popcount, value) pairs
    // Return 1 if sorted_data[idx_i] > sorted_data[idx_j]
    assign pop_a_gt_pop_b = (popcount[idx_i] > popcount[idx_j]);
    assign pop_a_eq_pop_b = (popcount[idx_i] == popcount[idx_j]);
    assign val_a_gt_val_b = (sorted_data[idx_i] > sorted_data[idx_j]);
    assign comp_a_greater_b = pop_a_gt_pop_b || (pop_a_eq_pop_b && val_a_gt_val_b);

    // FSM State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 1'b0;
            cnt_idx <= 4'd0;
            idx_i <= 3'd0;
            idx_j <= 3'd0;
            cycle_count <= 4'd0;
            passes <= 4'd0;
            temp_val <= 8'd0;
            temp_pop <= 4'd0;
            // Initialize arrays
            for (integer i = 0; i < 8; i = i + 1) begin
                data[i] <= 8'd0;
                sorted_data[i] <= 8'd0;
                result[i] <= 8'd0;
                popcount[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Start pulse received
                    end
                end

                LATCH: begin
                    // Latch input array into internal registers
                    for (integer i = 0; i < 8; i = i + 1) begin
                        data[i] <= arr[i];
                        sorted_data[i] <= arr[i];
                    end
                    cnt_idx <= 4'd0;
                end

                COUNT: begin
                    // Compute popcount for each element
                    if (cnt_idx < 8) begin
                        popcount[cnt_idx] <= calc_popcount(sorted_data[cnt_idx]);
                        cnt_idx <= cnt_idx + 4'd1;
                    end
                end

                SORT: begin
                    // Bubble sort: 8 passes, 7 comparisons each
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (passes < 4'd8) begin
                        // Perform one comparison/swap
                        if (comp_a_greater_b) begin
                            // Swap values
                            temp_val <= sorted_data[idx_i];
                            sorted_data[idx_i] <= sorted_data[idx_j];
                            sorted_data[idx_j] <= temp_val;
                            // Swap popcounts (recalculate for simplicity)
                            popcount[idx_i] <= calc_popcount(sorted_data[idx_j]);
                            popcount[idx_j] <= calc_popcount(sorted_data[idx_i]);
                        end
                        
                        // Move to next comparison
                        idx_j <= idx_j + 3'd1;
                        if (idx_j >= 3'd6) begin
                            // End of inner loop
                            idx_i <= 3'd0;
                            idx_j <= 3'd1;
                            passes <= passes + 4'd1;
                        end else begin
                            idx_i <= idx_j;
                        end
                    end
                end

                OUTPUT: begin
                    // Drive output ports
                    for (integer i = 0; i < 8; i = i + 1) begin
                        result[i] <= sorted_data[i];
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LATCH;
                end else begin
                    next_state = IDLE;
                end
            end

            LATCH: begin
                next_state = COUNT;
            end

            COUNT: begin
                if (cnt_idx >= 4'd8) begin
                    next_state = SORT;
                end else begin
                    next_state = COUNT;
                end
            end

            SORT: begin
                // Safety: max 128 cycles (8 passes * 7 comparisons + overhead)
                // Use passes to determine completion
                if (passes >= 4'd8 || cycle_count >= 4'd15) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = SORT;
                end
            end

            OUTPUT: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule