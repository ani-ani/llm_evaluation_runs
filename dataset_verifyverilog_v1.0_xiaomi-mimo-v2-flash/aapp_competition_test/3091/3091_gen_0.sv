module KenKenSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [7:0] m,
    input wire [31:0] t,
    input wire [7:0] op,
    input wire [9:0][3:0] row,
    input wire [9:0][3:0] col,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_CONSTRAINTS = 3'd1;
    localparam [2:0] VERIFY_ASSIGNMENT = 3'd2;
    localparam [2:0] UPDATE_COUNTER = 3'd3;
    localparam [2:0] ADVANCE_PERMUTATION = 3'd4;
    localparam [2:0] FINISHED = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;

    // Permutation tracking
    reg [9:0][3:0] values; // Current assignment for each cell
    reg [9:0][3:0] indices; // Indices 0..(n-1) to generate permutations
    reg [9:0][3:0] valid_indices; // Sorted indices for current segment
    reg [9:0][3:0] next_indices; // For generating next permutation
    
    // Loop counters
    reg [7:0] i, j, k;
    reg [7:0] loop_limit;
    
    // Row/col occupancy bit vectors (max 9 rows/cols, 9 bits needed)
    reg [8:0] row_occupancy;
    reg [8:0] col_occupancy;
    
    // Arithmetic calculation registers
    reg [31:0] sum_val;
    reg [31:0] prod_val;
    reg [31:0] max_val;
    reg [31:0] min_val;
    reg [31:0] diff_val;
    
    // Computation flags
    reg constraint_passed;
    reg row_unique;
    reg col_unique;
    reg all_unique;
    
    // Cycle counter for timeout
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // --- STATE MACHINE ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            // Initialize all arrays
            for (i = 0; i < 10; i = i + 1) begin
                values[i] <= 4'd0;
                indices[i] <= 4'd0;
                valid_indices[i] <= 4'd0;
                next_indices[i] <= 4'd0;
            end
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            loop_limit <= 8'd0;
            row_occupancy <= 9'd0;
            col_occupancy <= 9'd0;
            sum_val <= 32'd0;
            prod_val <= 32'd1;
            max_val <= 32'd0;
            min_val <= 32'd0;
            diff_val <= 32'd0;
            constraint_passed <= 1'b0;
            row_unique <= 1'b0;
            col_unique <= 1'b0;
            all_unique <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    result <= 32'd0;
                    if (start) begin
                        // Initialize indices 0..(n-1) for first segment
                        for (i = 0; i < 10; i = i + 1) begin
                            if (i < n) begin
                                valid_indices[i] <= i[3:0];
                            end else begin
                                valid_indices[i] <= 4'd0;
                            end
                        end
                        // Fill values with 0 initially
                        for (i = 0; i < 10; i = i + 1) begin
                            values[i] <= 4'd0;
                        end
                        loop_limit <= (m > 10) ? 8'd10 : m;
                        i <= 8'd0;
                        j <= 8'd0;
                        k <= 8'd0;
                        row_occupancy <= 9'd0;
                        col_occupancy <= 9'd0;
                        sum_val <= 32'd0;
                        prod_val <= 32'd1;
                        max_val <= 32'd0;
                        min_val <= 32'd0;
                        diff_val <= 32'd0;
                        constraint_passed <= 1'b0;
                        row_unique <= 1'b0;
                        col_unique <= 1'b0;
                        all_unique <= 1'b0;
                    end
                end

                CHECK_CONSTRAINTS: begin
                    // Check row and column uniqueness
                    row_occupancy <= 9'd0;
                    col_occupancy <= 9'd0;
                    row_unique <= 1'b1;
                    col_unique <= 1'b1;
                    i <= 8'd0;
                end

                VERIFY_ASSIGNMENT: begin
                    // Calculate arithmetic values
                    sum_val <= 32'd0;
                    prod_val <= 32'd1;
                    max_val <= 32'd0;
                    min_val <= 32'd0;
                    diff_val <= 32'd0;
                    constraint_passed <= 1'b0;
                    i <= 8'd0;
                end

                UPDATE_COUNTER: begin
                    if (all_unique && constraint_passed) begin
                        result <= result + 32'd1;
                    end
                end

                ADVANCE_PERMUTATION: begin
                    cycle_count <= cycle_count + 16'd1;
                end

                FINISHED: begin
                    done <= 1'b1;
                end
            endcase

            // --- Internal Logic ---
            
            // CHECK_CONSTRAINTS: Row/Col uniqueness check
            if (state == CHECK_CONSTRAINTS && i < loop_limit) begin
                // Check row
                if (row_occupancy[row[i]]) begin
                    row_unique <= 1'b0;
                end else begin
                    row_occupancy[row[i]] <= 1'b1;
                end
                // Check col
                if (col_occupancy[col[i]]) begin
                    col_unique <= 1'b0;
                end else begin
                    col_occupancy[col[i]] <= 1'b1;
                end
                i <= i + 8'd1;
            end else if (state == CHECK_CONSTRAINTS && i >= loop_limit) begin
                all_unique <= row_unique & col_unique;
                // Move to VERIFY
            end

            // VERIFY_ASSIGNMENT: Check arithmetic
            if (state == VERIFY_ASSIGNMENT) begin
                if (i < loop_limit) begin
                    // Accumulate values based on operator
                    case (op)
                        8'h2B: begin // '+'
                            sum_val <= sum_val + values[i];
                        end
                        8'h2D: begin // '-'
                            if (i == 0) begin
                                max_val <= values[i];
                                min_val <= values[i];
                            end else begin
                                if (values[i] > max_val) max_val <= values[i];
                                if (values[i] < min_val) min_val <= values[i];
                            end
                        end
                        8'h2A: begin // '*'
                            prod_val <= prod_val * values[i];
                        end
                        8'h2F: begin // '/'
                            if (i == 0) begin
                                max_val <= values[i];
                                min_val <= values[i];
                            end else begin
                                if (values[i] > max_val) max_val <= values[i];
                                if (values[i] < min_val) min_val <= values[i];
                            end
                        end
                    endcase
                    i <= i + 8'd1;
                end else begin
                    // Finished accumulating
                    case (op)
                        8'h2B: begin // '+'
                            constraint_passed <= (sum_val == t);
                        end
                        8'h2D: begin // '-'
                            if (loop_limit == 2) begin
                                diff_val <= (max_val > min_val) ? (max_val - min_val) : (min_val - max_val);
                                // Delayed check for subtraction
                            end
                        end
                        8'h2A: begin // '*'
                            constraint_passed <= (prod_val == t);
                        end
                        8'h2F: begin // '/'
                            if (loop_limit == 2 && min_val != 0) begin
                                // Integer division check: max / min == t
                                constraint_passed <= (max_val / min_val == t);
                            end
                        end
                    endcase
                end
            end
            
            // Fix for subtraction delay check
            if (state == VERIFY_ASSIGNMENT && i >= loop_limit && op == 8'h2D && loop_limit == 2) begin
                constraint_passed <= (diff_val == t);
            end

            // ADVANCE_PERMUTATION: Generate next permutation
            if (state == ADVANCE_PERMUTATION) begin
                // Copy valid_indices to indices for processing
                for (j = 0; j < 10; j = j + 1) begin
                    if (j < loop_limit) begin
                        indices[j] <= valid_indices[j];
                    end
                end
                // Reset value generation
                for (j = 0; j < 10; j = j + 1) begin
                    values[j] <= 4'd0;
                end
                i <= 8'd0;
            end
            
            // Generate next set of values for current indices
            if (state == ADVANCE_PERMUTATION) begin
                // Use existing indices to fill values: value[i] = indices[i] + 1
                if (i < loop_limit) begin
                    values[i] <= indices[i] + 4'd1;
                    i <= i + 8'd1;
                end
                // Check for permutation completion and generate next indices
                else if (i == loop_limit && k < loop_limit) begin
                    // Find the rightmost index that can be incremented
                    // Logic: scan from right to find an index that can be incremented
                    // Implementation simplified: iterate through indices to find next permutation
                    // Actually, let's implement a standard next_permutation logic
                    
                    // Step 1: Find rightmost index where valid_indices[i] < valid_indices[i+1]
                    // Step 2: Find rightmost element to swap
                    // Step 3: Reverse suffix
                    // Due to complexity, we implement a bounded counter approach or state-based next_permutation
                    
                    // Let's do: Find pivot
                    if (valid_indices[loop_limit - 1] < n[3:0] - loop_limit) begin
                        // Increment last
                        valid_indices[loop_limit - 1] <= valid_indices[loop_limit - 1] + 4'd1;
                    end else begin
                        // Need to propagate carry
                        // Reset loop vars for propagation
                    end
                    // (This part is complex to implement fully iterative without state loops)
                    // We will simulate a bounded search using a single loop variable i 
                    // representing the current cell index to try incrementing.
                    
                    // REVISED APPROACH FOR ADVANCE: 
                    // We iterate `i` from 0 to loop_limit. 
                    // At `i`, we try valid_indices[i]++. 
                    // If valid_indices[i] reaches limit, reset it to previous + 1 and decrement i.
                    // This simulates backtracking.
                    
                    if (k < loop_limit) begin
                        // Try increment at position k
                        if (valid_indices[k] < n[3:0] - loop_limit + k) begin
                            valid_indices[k] <= valid_indices[k] + 4'd1;
                            // Reset suffix
                            for (j = k + 1; j < loop_limit; j = j + 1) begin
                                valid_indices[j] <= valid_indices[j - 1] + 4'd1;
                            end
                            k <= 8'd0; // Reset for value generation
                        end else begin
                            k <= k + 8'd1; // Try next position
                        end
                    end else begin
                        // Finished all permutations for this segment
                        // (Segment handling is omitted as per spec "Enumerate all permutations for m cells")
                        // Assuming the input row/col arrays only define the section.
                        // We must handle the case where we exhaust permutations.
                        k <= loop_limit; // Stop
                    end
                end
            end
        end
    end

    // --- NEXT STATE LOGIC ---
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (m > 0 && m <= 10 && n >= m) begin
                        next_state = CHECK_CONSTRAINTS;
                    end else begin
                        next_state = FINISHED; // Invalid input
                    end
                end
            end

            CHECK_CONSTRAINTS: begin
                if (i >= loop_limit) begin
                    next_state = VERIFY_ASSIGNMENT;
                end
            end

            VERIFY_ASSIGNMENT: begin
                if (i >= loop_limit) begin
                    // Wait for computation
                    next_state = UPDATE_COUNTER;
                end
            end

            UPDATE_COUNTER: begin
                next_state = ADVANCE_PERMUTATION;
            end

            ADVANCE_PERMUTATION: begin
                // Check if we have finished all permutations
                // A simple check: if k exceeds loop_limit, we are done
                if (k >= loop_limit) begin
                    next_state = FINISHED;
                end else if (i >= loop_limit) begin
                    // Permutation advanced, go check constraints
                    next_state = CHECK_CONSTRAINTS;
                end else begin
                    // Still generating values
                    next_state = ADVANCE_PERMUTATION;
                end
            end

            FINISHED: begin
                next_state = IDLE; // Return to idle after done pulse
            end

            default: next_state = IDLE;
        endcase
        
        // Timeout override
        if (cycle_count >= MAX_CYCLES && state != FINISHED && state != IDLE) begin
            next_state = FINISHED;
        end
    end

endmodule