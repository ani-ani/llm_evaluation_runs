module courier_partition(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_customers,
    input [9:0] customer_x [0:7],
    input [9:0] customer_y [0:7],
    output reg [9:0] min_max_diameter,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam INIT_PARTITION = 3'b001;
    localparam COMPUTE_DIAMETER_1 = 3'b010;
    localparam COMPUTE_DIAMETER_2 = 3'b011;
    localparam UPDATE_MIN = 3'b100;
    localparam NEXT_PARTITION = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [7:0] partition; // 8-bit mask for 8 possible customers
    reg [7:0] mask_1; // current mask for group 1 (bits=1)
    reg [7:0] mask_2; // current mask for group 2 (bits=0)
    reg [3:0] i, j; // pairwise iteration indices
    reg [3:0] idx1, idx2; // indices of current pair
    reg [9:0] curr_diam_1, curr_diam_2; // diameters for current partition
    reg [9:0] dist; // current distance
    reg [2:0] cnt_1, cnt_2; // count customers in each group
    reg [2:0] cust_idx; // index for counting customers
    
    // Helper logic to map bits to actual customer indices
    reg [2:0] map_idx1, map_idx2; // mapped indices based on actual customers present
    reg [7:0] bit_check1, bit_check2;
    reg found1, found2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_max_diameter <= 10'h3FF; // max value
            done <= 1'b0;
            partition <= 8'b0;
            curr_diam_1 <= 10'b0;
            curr_diam_2 <= 10'b0;
            i <= 4'b0;
            j <= 4'b0;
            cnt_1 <= 3'b0;
            cnt_2 <= 3'b0;
            cust_idx <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_PARTITION;
                        min_max_diameter <= 10'h3FF;
                        partition <= 8'b0;
                    end
                end
                
                INIT_PARTITION: begin
                    // Prepare for this partition
                    // Build masks based on partition and num_customers
                    // Only consider bits [num_customers-1:0]
                    mask_1 <= partition;
                    mask_2 <= partition;
                    
                    // Initialize diameter computation
                    curr_diam_1 <= 10'b0;
                    curr_diam_2 <= 10'b0;
                    i <= 4'b0;
                    j <= 4'b1;
                    cust_idx <= 3'b0;
                    cnt_1 <= 3'b0;
                    cnt_2 <= 3'b0;
                    
                    // Check if partition is valid (not all 0s or all 1s)
                    // But spec says compute for all 2^N, so we compute even for empty groups
                    state <= COMPUTE_DIAMETER_1;
                end
                
                COMPUTE_DIAMETER_1: begin
                    // Calculate diameter for group 1 (bits=1)
                    // First, count customers in group 1
                    if (cust_idx < num_customers) begin
                        if (partition[cust_idx]) begin
                            cnt_1 <= cnt_1 + 1'b1;
                        end
                        cust_idx <= cust_idx + 1'b1;
                    end else begin
                        cust_idx <= 3'b0;
                        i <= 4'b0;
                        j <= 4'b1;
                        if (cnt_1 <= 3'd1) begin
                            // 0 or 1 customer -> diameter 0
                            curr_diam_1 <= 10'b0;
                            state <= COMPUTE_DIAMETER_2;
                        end else begin
                            state <= 3'b111; // Use unused state or sub-state
                        end
                    end
                end
                
                3'b111: begin // Sub-state for Pairwise Loop Group 1
                    // Find the i-th and j-th set bits in partition
                    if (i < num_customers) begin
                        // Find next pair
                        if (j < num_customers) begin
                            // Check if i and j are in group 1
                            if (partition[i] && partition[j]) begin
                                // Calculate Manhattan distance
                                if (customer_x[i] > customer_x[j])
                                    dist <= (customer_x[i] - customer_x[j]) + ((customer_y[i] > customer_y[j]) ? (customer_y[i] - customer_y[j]) : (customer_y[j] - customer_y[i]));
                                else
                                    dist <= (customer_x[j] - customer_x[i]) + ((customer_y[i] > customer_y[j]) ? (customer_y[i] - customer_y[j]) : (customer_y[j] - customer_y[i]));
                                
                                // Update max distance
                                if (dist > curr_diam_1) curr_diam_1 <= dist;
                                j <= j + 1'b1;
                            end else begin
                                j <= j + 1'b1;
                            end
                        end else begin
                            // Next i
                            i <= i + 1'b1;
                            j <= i + 2'b10;
                        end
                        
                        // Check completion
                        if (i >= num_customers - 1) begin
                            state <= COMPUTE_DIAMETER_2;
                            cust_idx <= 3'b0;
                            cnt_2 <= 3'b0;
                        end
                    end else begin
                        state <= COMPUTE_DIAMETER_2;
                        cust_idx <= 3'b0;
                        cnt_2 <= 3'b0;
                    end
                end
                
                COMPUTE_DIAMETER_2: begin
                    // Calculate diameter for group 2 (bits=0)
                    if (cust_idx < num_customers) begin
                        if (!partition[cust_idx]) begin
                            cnt_2 <= cnt_2 + 1'b1;
                        end
                        cust_idx <= cust_idx + 1'b1;
                    end else begin
                        cust_idx <= 3'b0;
                        i <= 4'b0;
                        j <= 4'b1;
                        if (cnt_2 <= 3'd1) begin
                            curr_diam_2 <= 10'b0;
                            state <= UPDATE_MIN;
                        end else begin
                            state <= 3'b110; // Sub-state for Group 2
                        end
                    end
                end
                
                3'b110: begin // Sub-state for Pairwise Loop Group 2
                    if (i < num_customers) begin
                        if (j < num_customers) begin
                            if (!partition[i] && !partition[j]) begin
                                // Calculate Manhattan distance
                                if (customer_x[i] > customer_x[j])
                                    dist <= (customer_x[i] - customer_x[j]) + ((customer_y[i] > customer_y[j]) ? (customer_y[i] - customer_y[j]) : (customer_y[j] - customer_y[i]));
                                else
                                    dist <= (customer_x[j] - customer_x[i]) + ((customer_y[i] > customer_y[j]) ? (customer_y[i] - customer_y[j]) : (customer_y[j] - customer_y[i]));
                                
                                if (dist > curr_diam_2) curr_diam_2 <= dist;
                                j <= j + 1'b1;
                            end else begin
                                j <= j + 1'b1;
                            end
                        end else begin
                            i <= i + 1'b1;
                            j <= i + 2'b10;
                        end
                        
                        if (i >= num_customers - 1) begin
                            state <= UPDATE_MIN;
                        end
                    end else begin
                        state <= UPDATE_MIN;
                    end
                end
                
                UPDATE_MIN: begin
                    // Compare max of two groups with current min
                    if (curr_diam_1 > curr_diam_2) begin
                        if (curr_diam_1 < min_max_diameter)
                            min_max_diameter <= curr_diam_1;
                    end else begin
                        if (curr_diam_2 < min_max_diameter)
                            min_max_diameter <= curr_diam_2;
                    end
                    state <= NEXT_PARTITION;
                end
                
                NEXT_PARTITION: begin
                    // Increment partition
                    if (partition == {num_customers{1'b1}}) begin
                        // All partitions done (including 11...1)
                        // Need to handle 00...0 as well? 
                        // Standard iteration 0 to 2^N-1 covers all partitions.
                        // Note: 00...0 is covered, 11...1 is covered.
                        // If partition is max (all 1s), we are done.
                        state <= DONE;
                    end else begin
                        // Logic to increment: find first 0, set to 1, clear lower bits
                        // Simplified: incrementing binary counter
                        if (partition == 8'b0) begin
                             // Special case: 00...0 -> 00...01 is next (00...0 is first)
                             // Actually, if we start at 0, next is 1. 
                             // Let's just increment as binary.
                             partition <= partition + 1'b1;
                        end else if (partition < (8'b1 << num_customers)) begin
                             partition <= partition + 1'b1;
                        end else begin
                             // Reached limit
                             state <= DONE;
                        end
                        
                        // Correction: Loop condition.
                        // Total 2^N partitions.
                        // We start at 0. End at 2^N - 1.
                        // If partition == (1<<num_customers) - 1, next is Done.
                        if (partition == ((8'b1 << num_customers) - 1'b1)) begin
                            state <= DONE;
                        end else begin
                            partition <= partition + 1'b1;
                            state <= INIT_PARTITION;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to reset
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
