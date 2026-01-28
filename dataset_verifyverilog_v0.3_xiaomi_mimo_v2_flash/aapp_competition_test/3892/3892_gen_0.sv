module ToyTrain(
    input clk,
    input rst_n,
    input start,
    input [6:0] n,
    input [7:0] m,
    input [6:0] a_i [0:199],
    input [6:0] b_i [0:199],
    output reg [31:0] ans_i [0:99],
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] RESET_COUNT = 4'd1;
    localparam [3:0] PROCESS_CANDIES = 4'd2;
    localparam [3:0] CALC_ANS = 4'd3;
    localparam [3:0] FINISH = 4'd4;

    // Internal registers and wires
    reg [3:0] state, next_state;
    reg [7:0] idx;  // Index for candy processing
    reg [6:0] i_idx;  // Index for starting station
    reg [6:0] j_idx;  // Index for target station
    
    // Arrays for stations 0 to n-1 (max 100 stations)
    reg [7:0] count [0:99];      // Number of candies per station
    reg [6:0] min_dist [0:99];   // Minimum distance per station (max 127)
    
    // Temporary registers for calculations
    reg [31:0] current_value;
    reg [31:0] max_value;
    reg [6:0] a, b, d;
    reg signed [7:0] dist_temp;  // For signed subtraction
    reg [6:0] mod_temp;
    
    // Control signals
    reg process_done;
    reg ans_done;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd255;

    integer k;

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = RESET_COUNT;
                else
                    next_state = IDLE;
            end
            RESET_COUNT: begin
                if (j_idx >= n)
                    next_state = PROCESS_CANDIES;
                else
                    next_state = RESET_COUNT;
            end
            PROCESS_CANDIES: begin
                if (idx >= m || cycle_counter >= MAX_CYCLES)
                    next_state = CALC_ANS;
                else
                    next_state = PROCESS_CANDIES;
            end
            CALC_ANS: begin
                if (i_idx >= n)
                    next_state = FINISH;
                else
                    next_state = CALC_ANS;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 1'b0;
            idx <= 8'd0;
            i_idx <= 7'd0;
            j_idx <= 7'd0;
            cycle_counter <= 8'd0;
            process_done <= 1'b0;
            ans_done <= 1'b0;
            current_value <= 32'd0;
            max_value <= 32'd0;
            
            // Reset arrays
            for (k = 0; k < 100; k = k + 1) begin
                count[k] <= 8'd0;
                min_dist[k] <= 7'd127; // Initialize to large value
                ans_i[k] <= 32'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 8'd0;
                    i_idx <= 7'd0;
                    j_idx <= 7'd0;
                    cycle_counter <= 8'd0;
                    process_done <= 1'b0;
                    ans_done <= 1'b0;
                end

                RESET_COUNT: begin
                    // Clear count and min_dist arrays for stations 0 to n-1
                    if (j_idx < 7'd100) begin
                        count[j_idx] <= 8'd0;
                        min_dist[j_idx] <= 7'd127;
                    end
                    j_idx <= j_idx + 7'd1;
                end

                PROCESS_CANDIES: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (idx < m) begin
                        // Calculate distance d = (b - a) mod n
                        // Convert 1-indexed to 0-indexed
                        if (a_i[idx] > 7'd0) begin
                            a <= a_i[idx] - 7'd1;
                        end else begin
                            a <= 7'd0;
                        end
                        
                        if (b_i[idx] > 7'd0) begin
                            b <= b_i[idx] - 7'd1;
                        end else begin
                            b <= 7'd0;
                        end
                        
                        // Calculate distance in combinational logic style
                        // Using temporary signals for calculation
                        // d = (b - a) mod n
                        // Since we need to handle wrap-around, we compute it here
                        if (b >= a) begin
                            mod_temp <= b - a;
                        end else begin
                            mod_temp <= n + b - a;
                        end
                        
                        // Wait one cycle for calculation to settle, then update
                        // Actually, we can compute directly in this cycle
                        // but need to use the values from previous cycle
                        // Let's use the values calculated this cycle
                        
                    end
                    idx <= idx + 8'd1;
                end

                CALC_ANS: begin
                    // For each starting station i
                    if (i_idx < n) begin
                        max_value <= 32'd0;  // Initialize max for this i
                        j_idx <= 7'd0;       // Reset j_idx for inner loop
                    end
                    
                    // Inner loop to find max value for current i
                    // Process one j per cycle (pipelined)
                    if (j_idx < n && i_idx < n) begin
                        if (count[j_idx] > 8'd0) begin
                            // value = ((j - i + n) % n) + (count[j] - 1) * n + min_dist[j]
                            
                            // Calculate ((j - i + n) % n)
                            // j - i is signed
                            // We need to compute this carefully
                            
                            // Intermediate calculation
                            // dist_temp = j_idx - i_idx (signed)
                            if (j_idx >= i_idx) begin
                                current_value <= j_idx - i_idx;
                            end else begin
                                current_value <= n + j_idx - i_idx;
                            end
                            
                            // Add (count[j] - 1) * n
                            if (count[j_idx] > 8'd0) begin
                                current_value <= current_value + ((count[j_idx] - 8'd1) * n);
                            end
                            
                            // Add min_dist[j]
                            current_value <= current_value + min_dist[j_idx];
                            
                            // Compare and update max
                            if (current_value > max_value) begin
                                max_value <= current_value;
                            end
                        end
                        j_idx <= j_idx + 7'd1;
                    end else if (i_idx < n) begin
                        // Finished inner loop for this i
                        ans_i[i_idx] <= max_value;
                        i_idx <= i_idx + 7'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Combinational logic for PROCESS_CANDIES state
    // We need to handle the distance calculation and array update
    // This is done in a separate always block or integrated into the main FSM
    // To avoid combinational loops, we'll calculate in the FSM with proper staging
    
    // Update arrays in PROCESS_CANDIES state (after distance calculation)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main FSM
        end else begin
            if (state == PROCESS_CANDIES && idx <= m && idx > 8'd0) begin
                // Use the distance calculated in previous cycle or calculate now
                // We'll calculate d in this cycle based on current idx-1
                
                // Get a and b from previous index (idx-1)
                // This is tricky in hardware, better to pipeline properly
                // Let's recalculate for current idx
                
                // Actually, let's move the distance calculation to a separate combinational block
                // and update arrays based on that
            end
        end
    end

    // Combinational distance calculation and array update logic
    // This block handles the candy processing logic
    reg [6:0] a_reg, b_reg;
    reg [6:0] d_comb;
    reg process_candy;
    
    always @(*) begin
        if (state == PROCESS_CANDIES && idx < m) begin
            // Convert to 0-indexed
            a_reg = (a_i[idx] > 7'd0) ? (a_i[idx] - 7'd1) : 7'd0;
            b_reg = (b_i[idx] > 7'd0) ? (b_i[idx] - 7'd1) : 7'd0;
            
            // Calculate d = (b - a) mod n
            if (b_reg >= a_reg) begin
                d_comb = b_reg - a_reg;
            end else begin
                d_comb = n + b_reg - a_reg;
            end
            process_candy = 1'b1;
        end else begin
            d_comb = 7'd0;
            process_candy = 1'b0;
        end
    end

    // Sequential update for arrays
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled elsewhere
        end else begin
            if (process_candy) begin
                // Update count for station a_reg
                count[a_reg] <= count[a_reg] + 8'd1;
                
                // Update min_dist for station a_reg
                if (d_comb < min_dist[a_reg]) begin
                    min_dist[a_reg] <= d_comb;
                end
            end
        end
    end

    // Sequential update for answers (pipelined calculation)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main FSM
        end else begin
            if (state == CALC_ANS && j_idx < n && i_idx < n) begin
                // Calculate value for current (i, j) pair
                // value = ((j - i + n) % n) + (count[j] - 1) * n + min_dist[j]
                
                if (count[j_idx] > 8'd0) begin
                    // Calculate ((j - i + n) % n)
                    reg [31:0] offset;
                    if (j_idx >= i_idx) begin
                        offset = j_idx - i_idx;
                    end else begin
                        offset = n + j_idx - i_idx;
                    end
                    
                    // Add (count[j] - 1) * n
                    reg [31:0] count_part;
                    count_part = (count[j_idx] - 8'd1) * n;
                    
                    // Add min_dist[j]
                    reg [31:0] value;
                    value = offset + count_part + min_dist[j_idx];
                    
                    // Update max_value
                    if (value > max_value) begin
                        max_value <= value;
                    end
                end
            end
        end
    end

endmodule