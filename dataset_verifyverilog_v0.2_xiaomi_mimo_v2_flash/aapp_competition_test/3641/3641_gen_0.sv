module necklace_splitter(
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [2:0] n,
    input [7:0] beads [0:7],
    output reg result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CHECK_TOTAL = 3'b001;
    localparam PREPARE_CUTS = 3'b010;
    localparam VALIDATE = 3'b011;
    localparam UPDATE_RESULT = 3'b100;
    localparam FINISH = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [10:0] total_sum;      // Max 8*255 = 2040, needs 11 bits
    reg [10:0] target_sum;     // Same as total_sum/k
    reg [2:0] current_start;   // Current starting position
    reg [2:0] segment_count;   // Current segment being checked
    reg [10:0] current_sum;    // Sum of current segment
    reg [3:0] cut_mask;        // k-1 cuts among n-1 positions
    reg [3:0] max_cut_mask;    // Maximum mask value for given n and k
    reg valid_config;          // Flag for current config
    reg [2:0] bead_index;      // Index for current bead being added to segment
    reg [2:0] segment_bead_count; // Count of beads in current segment

    // Combinational helper signals
    reg [10:0] next_sum;
    reg [2:0] next_index;
    reg [3:0] next_mask;
    reg is_cut;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            total_sum <= 0;
            target_sum <= 0;
            current_start <= 0;
            segment_count <= 0;
            current_sum <= 0;
            cut_mask <= 0;
            max_cut_mask <= 0;
            valid_config <= 0;
            bead_index <= 0;
            segment_bead_count <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 0;
                        result <= 0;
                        total_sum <= 0;
                        current_start <= 0;
                        cut_mask <= 0;
                    end
                end

                CHECK_TOTAL: begin
                    // Compute total sum
                    total_sum <= beads[0] + beads[1] + beads[2] + beads[3] + 
                                 beads[4] + beads[5] + beads[6] + beads[7];
                end

                PREPARE_CUTS: begin
                    // Set target and max_cut_mask based on n and k
                    target_sum <= total_sum / k;
                    
                    // Calculate maximum cuts: n-1 choose k-1
                    // For n=8, k=4: cuts needed = 3, max combinations
                    // We'll use bitmask approach
                    case ({n, k})
                        6'b001001: max_cut_mask <= 4'b0001; // n=2, k=2: 1 cut
                        6'b001010: max_cut_mask <= 4'b0011; // n=3, k=2: 2 cuts possible
                        6'b001011: max_cut_mask <= 4'b0111; // n=4, k=3: 3 cuts
                        default: max_cut_mask <= 4'b1111;
                    endcase
                    cut_mask <= 0;
                    current_start <= 0;
                end

                VALIDATE: begin
                    // Validate current configuration
                    if (valid_config && segment_count == k - 1 && current_sum == target_sum) begin
                        // Found valid configuration
                        result <= 1;
                    end else if (segment_count == k - 1 && current_sum != target_sum) begin
                        // This segment failed, will try next config
                        result <= result; // Keep previous result if any
                    end
                end

                UPDATE_RESULT: begin
                    // Increment cut_mask or current_start
                    if (cut_mask < max_cut_mask) begin
                        cut_mask <= cut_mask + 1;
                    end else begin
                        cut_mask <= 0;
                        current_start <= current_start + 1;
                    end
                end

                FINISH: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_TOTAL;
                else next_state = IDLE;
            end

            CHECK_TOTAL: begin
                if (k > 0 && total_sum % k != 0) begin
                    // Total not divisible by k, skip to finish
                    next_state = FINISH;
                end else if (k == 0 || k > 4) begin
                    next_state = FINISH;
                end else begin
                    next_state = PREPARE_CUTS;
                end
            end

            PREPARE_CUTS: begin
                next_state = VALIDATE;
            end

            VALIDATE: begin
                if (result) begin
                    // Found valid config, finish
                    next_state = FINISH;
                end else if (cut_mask >= max_cut_mask && current_start >= n - 1) begin
                    // All configurations tried, no valid found
                    next_state = FINISH;
                end else if (segment_count == k - 1 && current_sum != target_sum) begin
                    // Current config failed, try next
                    next_state = UPDATE_RESULT;
                end else begin
                    // Continue with current config
                    next_state = VALIDATE;
                end
            end

            UPDATE_RESULT: begin
                next_state = PREPARE_CUTS;
            end

            FINISH: begin
                if (!start) next_state = IDLE;
                else next_state = FINISH;
            end

            default: next_state = IDLE;
        endcase
    end

    // Combinational segment sum calculation
    always @(*) begin
        // Calculate current segment sum for current start and cut_mask
        // This is a simplified version for synthesis
        integer i;
        reg [2:0] seg_start, seg_end;
        reg [10:0] seg_sum;
        reg [2:0] cuts [0:3];
        reg [2:0] num_cuts;
        
        // Parse cut_mask to get cut positions
        num_cuts = 0;
        for (i = 0; i < 4; i = i + 1) begin
            if (cut_mask[i]) begin
                cuts[num_cuts] = i + 1; // Cut after bead i
                num_cuts = num_cuts + 1;
            end
        end
        
        // Find segment boundaries for segment_count
        if (segment_count == 0) begin
            seg_start = current_start;
            if (num_cuts > 0) seg_end = cuts[0] - 1;
            else seg_end = current_start + (n / k) - 1;
        end else if (segment_count < num_cuts) begin
            seg_start = cuts[segment_count - 1];
            seg_end = cuts[segment_count] - 1;
        end else begin
            seg_start = (num_cuts == 0) ? current_start : cuts[num_cuts - 1];
            seg_end = current_start + n - 1;
        end
        
        // Handle circular wrapping
        seg_start = seg_start % n;
        seg_end = seg_end % n;
        
        // Calculate segment sum
        seg_sum = 0;
        i = seg_start;
        while (1) begin
            seg_sum = seg_sum + beads[i];
            if (i == seg_end) break;
            i = (i + 1) % n;
        end
        
        current_sum = seg_sum;
        is_cut = 0;
        next_sum = 0;
        next_index = 0;
        next_mask = 0;
    end

endmodule
