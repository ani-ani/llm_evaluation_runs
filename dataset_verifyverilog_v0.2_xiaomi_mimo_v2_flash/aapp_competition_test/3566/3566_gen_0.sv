module oostende_beach(
    input clk,
    input rst_n,
    input start,
    input [2:0] update_idx,
    input [9:0] update_val,
    output reg [2:0] optimal_k,
    output reg done
);

    // Parameters and Constants
    parameter N = 8;
    parameter HUT_W = 10;
    parameter SUM_W = 14; // log2(8 * 1024) approx 13. 14 bits is safe
    parameter IDX_W = 3;

    // State Encoding
    parameter IDLE = 3'b000;
    parameter UPDATE_ARRAY = 3'b001;
    parameter CALC_TOTAL = 3'b010;
    parameter CALC_LOOP = 3'b011;
    parameter DONE = 3'b100;

    // Memory for huts (Synchronous RAM inference)
    reg [HUT_W-1:0] huts [0:N-1];
    
    // State Machine Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Datapath Registers
    reg [IDX_W-1:0] k;
    reg [SUM_W-1:0] total_sum;
    reg [SUM_W-1:0] left_sum;
    reg [SUM_W-1:0] min_diff;
    reg [IDX_W-1:0] best_k;
    
    // Control Flags
    reg start_processing;
    wire start_pulse;

    // Signal Synchronization for Start
    reg start_sync1, start_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_sync1 <= 1'b0;
            start_sync2 <= 1'b0;
        end else begin
            start_sync1 <= start;
            start_sync2 <= start_sync1;
        end
    end
    assign start_pulse = start_sync1 & ~start_sync2;

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE:           next_state = start_pulse ? UPDATE_ARRAY : IDLE;
            UPDATE_ARRAY:   next_state = CALC_TOTAL;
            CALC_TOTAL:     next_state = CALC_LOOP;
            CALC_LOOP:      next_state = (k == N) ? DONE : CALC_LOOP;
            DONE:           next_state = start_pulse ? UPDATE_ARRAY : DONE;
            default:        next_state = IDLE;
        endcase
    end

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // Datapath Logic
    integer i;
    wire [HUT_W-1:0] current_hut_val;
    assign current_hut_val = huts[k];

    // Combinational calculations for the loop
    wire [SUM_W-1:0] center_left;
    wire [SUM_W-1:0] center_right;
    wire [SUM_W-1:0] right_sum;
    wire [SUM_W-1:0] left_queue;
    wire [SUM_W-1:0] right_queue;
    wire [SUM_W-1:0] diff;
    
    // Integer division: floor(val/2) is right shift
    assign center_left = {1'b0, current_hut_val[HUT_W-1:1]};
    // Integer ceil(val/2) is (val + 1) / 2. 
    // Note: 10 bit value, adding 1 keeps it within 10 bits, promoted to SUM_W.
    // Behavior: if val is even (LSB=0), val>>1 == (val+1)>>1 (e.g. 4->2, 5->2).
    // if val is odd (LSB=1), val>>1 != (val+1)>>1 (e.g. 3->1, 4->2).
    assign center_right = {1'b0, (current_hut_val + 1'b1) >> 1};
    
    assign right_sum = total_sum - left_sum - { { (SUM_W-HUT_W) {1'b0} }, current_hut_val };
    
    assign left_queue = left_sum + center_left;
    assign right_queue = right_sum + center_right;
    
    // Absolute difference
    assign diff = (left_queue >= right_queue) ? (left_queue - right_queue) : (right_queue - left_queue);

    // Sequential Logic for Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Logic
            huts[0] <= 0; huts[1] <= 0; huts[2] <= 0; huts[3] <= 0;
            huts[4] <= 0; huts[5] <= 0; huts[6] <= 0; huts[7] <= 0;
            optimal_k <= 0;
            done <= 1'b0;
            k <= 0;
            total_sum <= 0;
            left_sum <= 0;
            min_diff <= 0;
            best_k <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                UPDATE_ARRAY: begin
                    huts[update_idx] <= update_val;
                    // Reset loop counter
                    k <= 0;
                end

                CALC_TOTAL: begin
                    // Calculate total sum combinational or in 1 cycle
                    // For N=8, unrolled sum is fine.
                    total_sum <= huts[0] + huts[1] + huts[2] + huts[3] + 
                                 huts[4] + huts[5] + huts[6] + huts[7];
                    // Initialize loop vars
                    left_sum <= 0;
                    min_diff <= {SUM_W{1'b1}}; // Set to max value
                    best_k <= 0;
                    // k is 0 here effectively, but we stay in state for logic or advance. 
                    // According to sequence: Step 1..N. 
                    // If we want to process k=0 in this state, we would use combinational logic.
                    // If we want to process k=0 in next state, we increment k.
                    // Let's increment k to 1 so CALC_LOOP processes k=0 and stops when k=N (8).
                    // Wait, logic says: Step 0 (calc total), Step 1..N (calc k=0..7).
                    // So k starts at 0. 
                    k <= 0;
                end

                CALC_LOOP: begin
                    // k holds current index (0..7)
                    if (k < N) begin
                        // Compare and Update Min
                        // diff is combinational based on current k, left_sum, total_sum
                        if (diff < min_diff) begin
                            min_diff <= diff;
                            best_k <= k;
                        end
                        // Update left_sum for next iteration
                        // left_sum = left_sum + huts[k]
                        left_sum <= left_sum + { { (SUM_W-HUT_W) {1'b0} }, current_hut_val };
                        // Increment k
                        k <= k + 1;
                    end
                end

                DONE: begin
                    optimal_k <= best_k;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
