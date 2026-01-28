module MaxSubarraySwapSum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] k,
    output reg signed [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_LOOP = 3'd1;
    localparam [2:0] SORT_IN = 3'd2;
    localparam [2:0] SORT_OUT = 3'd3;
    localparam [2:0] SWAP_COMPUTE = 3'd4;
    localparam [2:0] UPDATE_MAX = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg signed [7:0] arr_reg [0:15];          // Store input array
    reg [3:0] k_reg;                          // Store k value
    reg signed [15:0] max_sum;               // Track maximum sum
    reg [4:0] l, r;                           // Subarray bounds (0-15)
    reg [4:0] in_len, out_len;                // Array lengths
    reg [3:0] swap_count;                     // Current swap count
    
    // Buffers for sorting and swapping
    reg signed [7:0] inside_buf [0:15];      // Subarray elements
    reg signed [7:0] outside_buf [0:15];     // Outside elements
    reg signed [7:0] temp_val;               // Temporary for sorting
    
    // Sorting network counters
    reg [4:0] sort_idx;
    reg [4:0] swap_idx;
    reg signed [15:0] current_sum;
    reg signed [15:0] current_max;
    
    // Counters for loops
    reg [3:0] swap_iter;
    reg [4:0] calc_idx;
    
    // Control flags
    reg sort_done;
    reg swap_done;
    reg sum_done;
    
    integer i;

    // Reset and State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            max_sum <= 16'sd0;
            l <= 5'd0;
            r <= 5'd0;
            swap_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                arr_reg[i] <= 8'sd0;
                inside_buf[i] <= 8'sd0;
                outside_buf[i] <= 8'sd0;
            end
            k_reg <= 4'd0;
            in_len <= 5'd0;
            out_len <= 5'd0;
            current_sum <= 16'sd0;
            current_max <= 16'sd0;
            sort_idx <= 5'd0;
            swap_idx <= 5'd0;
            swap_iter <= 4'd0;
            calc_idx <= 5'd0;
            sort_done <= 1'b0;
            swap_done <= 1'b0;
            sum_done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Store inputs
                        for (i = 0; i < 16; i = i + 1) begin
                            arr_reg[i] <= arr[i];
                        end
                        k_reg <= k;
                        max_sum <= 16'sd0;
                        l <= 5'd0;
                        r <= 5'd0;
                        current_max <= 16'sd0;
                    end
                end
                
                INIT_LOOP: begin
                    // Calculate array lengths
                    if (r >= l) begin
                        in_len <= (r - l + 1);
                        out_len <= (16 - (r - l + 1));
                        // Copy elements to buffers
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i >= l && i <= r) begin
                                inside_buf[i - l] <= arr_reg[i];
                            end else if (i < l) begin
                                outside_buf[i] <= arr_reg[i];
                            end else begin // i > r
                                outside_buf[i - (r - l + 1)] <= arr_reg[i];
                            end
                        end
                        sort_idx <= 5'd0;
                        sort_done <= 1'b0;
                    end
                end
                
                SORT_IN: begin
                    // Odd-even transposition sort for inside_buf (ascending)
                    if (in_len > 1) begin
                        if (sort_idx < in_len) begin
                            if (sort_idx[0] == 1'b0) begin // Even phase
                                if (sort_idx + 1 < in_len) begin
                                    if (inside_buf[sort_idx] > inside_buf[sort_idx + 1]) begin
                                        temp_val <= inside_buf[sort_idx];
                                        inside_buf[sort_idx] <= inside_buf[sort_idx + 1];
                                        inside_buf[sort_idx + 1] <= temp_val;
                                    end
                                end
                            end else begin // Odd phase
                                if (sort_idx - 1 >= 0 && sort_idx + 1 < in_len) begin
                                    if (inside_buf[sort_idx - 1] > inside_buf[sort_idx + 1]) begin
                                        temp_val <= inside_buf[sort_idx - 1];
                                        inside_buf[sort_idx - 1] <= inside_buf[sort_idx + 1];
                                        inside_buf[sort_idx + 1] <= temp_val;
                                    end
                                end
                            end
                            sort_idx <= sort_idx + 5'd1;
                        end else begin
                            sort_idx <= 5'd0;
                            sort_done <= 1'b1;
                        end
                    end else begin
                        sort_done <= 1'b1;
                    end
                end
                
                SORT_OUT: begin
                    // Odd-even transposition sort for outside_buf (descending)
                    if (out_len > 1) begin
                        if (sort_idx < out_len) begin
                            if (sort_idx[0] == 1'b0) begin // Even phase
                                if (sort_idx + 1 < out_len) begin
                                    if (outside_buf[sort_idx] < outside_buf[sort_idx + 1]) begin // Reverse comparison
                                        temp_val <= outside_buf[sort_idx];
                                        outside_buf[sort_idx] <= outside_buf[sort_idx + 1];
                                        outside_buf[sort_idx + 1] <= temp_val;
                                    end
                                end
                            end else begin // Odd phase
                                if (sort_idx - 1 >= 0 && sort_idx + 1 < out_len) begin
                                    if (outside_buf[sort_idx - 1] < outside_buf[sort_idx + 1]) begin
                                        temp_val <= outside_buf[sort_idx - 1];
                                        outside_buf[sort_idx - 1] <= outside_buf[sort_idx + 1];
                                        outside_buf[sort_idx + 1] <= temp_val;
                                    end
                                end
                            end
                            sort_idx <= sort_idx + 5'd1;
                        end else begin
                            sort_idx <= 5'd0;
                            swap_iter <= 4'd0;
                            swap_done <= 1'b1;
                        end
                    end else begin
                        swap_iter <= 4'd0;
                        swap_done <= 1'b1;
                    end
                end
                
                SWAP_COMPUTE: begin
                    // Perform swaps and compute sum
                    if (swap_iter < k_reg && swap_iter < in_len && swap_iter < out_len) begin
                        if (outside_buf[swap_iter] > inside_buf[swap_iter]) begin
                            // Swap: swap inside[swap_iter] with outside[swap_iter]
                            temp_val <= inside_buf[swap_iter];
                            inside_buf[swap_iter] <= outside_buf[swap_iter];
                            outside_buf[swap_iter] <= temp_val;
                        end
                        swap_iter <= swap_iter + 4'd1;
                    end else begin
                        // Compute sum of inside_buf
                        if (calc_idx < in_len) begin
                            current_sum <= current_sum + inside_buf[calc_idx];
                            calc_idx <= calc_idx + 5'd1;
                        end else begin
                            sum_done <= 1'b1;
                        end
                    end
                end
                
                UPDATE_MAX: begin
                    // Update max_sum
                    if (current_sum > max_sum) begin
                        max_sum <= current_sum;
                    end
                    // Reset for next subarray
                    current_sum <= 16'sd0;
                    calc_idx <= 5'd0;
                    swap_done <= 1'b0;
                    sum_done <= 1'b0;
                    // Update subarray bounds
                    if (r < 15) begin
                        r <= r + 5'd1;
                    end else if (l < 15) begin
                        l <= l + 5'd1;
                        r <= l + 5'd1; // Start r from l+1 for new l
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= max_sum;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_LOOP;
                else next_state = IDLE;
            end
            
            INIT_LOOP: begin
                next_state = SORT_IN;
            end
            
            SORT_IN: begin
                if (sort_done) next_state = SORT_OUT;
                else next_state = SORT_IN;
            end
            
            SORT_OUT: begin
                if (swap_done) next_state = SWAP_COMPUTE;
                else next_state = SORT_OUT;
            end
            
            SWAP_COMPUTE: begin
                if (sum_done) next_state = UPDATE_MAX;
                else next_state = SWAP_COMPUTE;
            end
            
            UPDATE_MAX: begin
                // Check if all subarrays processed
                if (l == 15 && r == 15) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = INIT_LOOP;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule