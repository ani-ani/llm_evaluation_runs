module NecklaceSplit(
    input clk,
    input rst_n,
    input start,
    input [3:0] k_i,
    input [3:0] n_i,
    input [15:0] bead_weights [0:15],
    output reg done,
    output reg [0:0] result
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_SUM = 3'd1;
    localparam [2:0] CHECK_DIV = 3'd2;
    localparam [2:0] TRY_START = 3'd3;
    localparam [2:0] CHECK_SEG = 3'd4;
    localparam [2:0] DONE = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] total_sum;
    reg [15:0] target_sum;
    reg [3:0] start_idx;
    reg [3:0] seg_idx;
    reg [3:0] current_idx;
    reg [15:0] current_seg_sum;
    reg [3:0] beads_used;
    reg success;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Helper wires for modular indexing
    wire [3:0] mod_idx;
    assign mod_idx = (current_idx >= n_i) ? (current_idx - n_i) : current_idx;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CALC_SUM : IDLE;
            
            CALC_SUM: next_state = CHECK_DIV;
            
            CHECK_DIV: begin
                if (k_i == 4'd0) next_state = DONE;
                else if (total_sum % k_i != 16'd0) next_state = DONE;
                else next_state = TRY_START;
            end
            
            TRY_START: begin
                if (start_idx >= n_i) next_state = DONE;
                else next_state = CHECK_SEG;
            end
            
            CHECK_SEG: begin
                if (seg_idx >= k_i) begin
                    // All segments complete and valid
                    next_state = DONE;
                end else if (beads_used >= n_i) begin
                    // Used all beads but not all segments - try next start
                    next_state = TRY_START;
                end else begin
                    // Continue checking current segment
                    next_state = CHECK_SEG;
                end
            end
            
            DONE: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            total_sum <= 16'd0;
            target_sum <= 16'd0;
            start_idx <= 4'd0;
            seg_idx <= 4'd0;
            current_idx <= 4'd0;
            current_seg_sum <= 16'd0;
            beads_used <= 4'd0;
            success <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        total_sum <= 16'd0;
                        target_sum <= 16'd0;
                        start_idx <= 4'd0;
                        seg_idx <= 4'd0;
                        current_idx <= 4'd0;
                        current_seg_sum <= 16'd0;
                        beads_used <= 4'd0;
                        success <= 1'b0;
                    end
                end
                
                CALC_SUM: begin
                    // Sum all beads from 0 to n-1
                    if (current_idx < n_i) begin
                        total_sum <= total_sum + bead_weights[current_idx];
                        current_idx <= current_idx + 4'd1;
                    end else begin
                        current_idx <= 4'd0;
                    end
                end
                
                CHECK_DIV: begin
                    if (k_i != 4'd0 && total_sum % k_i == 16'd0) begin
                        target_sum <= total_sum / k_i;
                        start_idx <= 4'd0;
                        success <= 1'b0;
                    end
                end
                
                TRY_START: begin
                    // Initialize for new start position
                    seg_idx <= 4'd0;
                    current_seg_sum <= 16'd0;
                    beads_used <= 4'd0;
                    current_idx <= start_idx;
                    success <= 1'b0;
                    if (start_idx < n_i) begin
                        start_idx <= start_idx + 4'd1;
                    end
                end
                
                CHECK_SEG: begin
                    // Check if we have completed all segments
                    if (seg_idx >= k_i) begin
                        // Success! All segments matched target
                        success <= 1'b1;
                        result <= 1'b1;
                    end else if (beads_used >= n_i) begin
                        // Failed - used all beads but didn't complete all segments
                        success <= 1'b0;
                    end else begin
                        // Add current bead to segment sum
                        current_seg_sum <= current_seg_sum + bead_weights[mod_idx];
                        beads_used <= beads_used + 4'd1;
                        current_idx <= current_idx + 4'd1;
                        
                        // Check if segment reached target
                        if (current_seg_sum + bead_weights[mod_idx] == target_sum) begin
                            // Segment complete, move to next
                            seg_idx <= seg_idx + 4'd1;
                            current_seg_sum <= 16'd0;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!success && k_i != 4'd0 && total_sum % k_i == 16'd0) begin
                        result <= 1'b0;
                    end
                    current_idx <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
            
            // Early termination if timeout or invalid
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE) begin
                state <= DONE;
                done <= 1'b1;
                result <= 1'b0;
            end
        end
    end

endmodule