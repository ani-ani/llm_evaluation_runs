module OptimalKCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] seq_in,
    input wire seq_valid,
    input wire seq_done,
    output reg [7:0] optimal_k,
    output reg [3:0] max_matches,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ_SEQ  = 3'd1;
    localparam [2:0] CALC_K    = 3'd2;
    localparam [2:0] CHECK_K   = 3'd3;
    localparam [2:0] UPDATE_BEST = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] seq_len;
    reg [7:0] seq_buffer [0:15];
    reg [7:0] k_candidates [0:15];
    reg [3:0] num_candidates;
    reg [3:0] current_candidate_idx;
    reg [7:0] current_k;
    reg [3:0] current_matches;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2048;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            seq_len <= 4'd0;
            optimal_k <= 8'd0;
            max_matches <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize sequence buffer
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                seq_buffer[i] <= 8'd0;
            end

            // Initialize candidate array
            for (i = 0; i < 16; i = i + 1) begin
                k_candidates[i] <= 8'd0;
            end

            num_candidates <= 4'd0;
            current_candidate_idx <= 4'd0;
            current_k <= 8'd0;
            current_matches <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= READ_SEQ;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                READ_SEQ: begin
                    if (seq_valid && !seq_done) begin
                        seq_buffer[seq_len] <= seq_in;
                        seq_len <= seq_len + 4'd1;
                        next_state <= READ_SEQ;
                    end else if (seq_done) begin
                        next_state <= CALC_K;
                    end else begin
                        next_state <= READ_SEQ;
                    end
                end

                CALC_K: begin
                    // Generate candidate K values from adjacent differences
                    integer i;
                    num_candidates <= 4'd0;
                    for (i = 0; i < 15; i = i + 1) begin
                        if (i < seq_len - 4'd1) begin
                            reg signed [8:0] diff;
                            diff = seq_buffer[i+1] - seq_buffer[i];
                            
                            // Only consider positive differences, clamp to 0-255
                            if (diff > 8'd0 && diff <= 8'd255) begin
                                k_candidates[num_candidates] <= diff[7:0];
                                num_candidates <= num_candidates + 4'd1;
                            end
                        end
                    end
                    
                    // Always include 0 as a candidate
                    k_candidates[num_candidates] <= 8'd0;
                    num_candidates <= num_candidates + 4'd1;
                    
                    current_candidate_idx <= 4'd0;
                    next_state <= CHECK_K;
                end

                CHECK_K: begin
                    if (current_candidate_idx < num_candidates) begin
                        current_k <= k_candidates[current_candidate_idx];
                        current_matches <= 4'd0;
                        
                        // Simulate playback and count matches
                        integer i;
                        reg signed [7:0] current_val;
                        current_val = seq_buffer[0];
                        
                        for (i = 1; i < seq_len; i = i + 1) begin
                            if (seq_buffer[i] > seq_buffer[i-1]) begin
                                current_val = current_val + current_k;
                            end else if (seq_buffer[i] < seq_buffer[i-1]) begin
                                current_val = current_val - current_k;
                            end
                            
                            if (current_val == seq_buffer[i]) begin
                                current_matches <= current_matches + 4'd1;
                            end
                        end
                        
                        next_state <= UPDATE_BEST;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                UPDATE_BEST: begin
                    if (current_matches > max_matches) begin
                        max_matches <= current_matches;
                        optimal_k <= current_k;
                    end
                    
                    current_candidate_idx <= current_candidate_idx + 4'd1;
                    next_state <= CHECK_K;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule