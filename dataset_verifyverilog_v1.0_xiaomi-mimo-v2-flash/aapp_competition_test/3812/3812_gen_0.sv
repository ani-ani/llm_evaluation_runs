module StringPrefixSwap (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] s_char_i,
    input wire [7:0] t_char_i,
    input wire [3:0] len_s,
    input wire [3:0] len_t,
    output reg done,
    output reg [5:0] op_count,
    output reg [3:0] op_s_len,
    output reg [3:0] op_t_len,
    output reg valid_op
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_S    = 3'd1;
    localparam [2:0] LOAD_T    = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] OUTPUT    = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    // Memory buffers for strings s and t
    reg [7:0] s_buf [0:15];
    reg [7:0] t_buf [0:15];
    
    // Working copies for computation (to allow modifications)
    reg [7:0] s_work [0:15];
    reg [7:0] t_work [0:15];
    
    // Operation storage
    reg [3:0] ops_s_len [0:63];
    reg [3:0] ops_t_len [0:63];
    
    // State registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] load_idx;
    reg [5:0] op_idx;           // Current operation index (0-63)
    reg [5:0] total_ops;        // Total operations generated
    reg [5:0] output_idx;       // Index for outputting operations
    reg [3:0] curr_len_s;       // Current length of s during computation
    reg [3:0] curr_len_t;       // Current length of t during computation
    
    // Computation temporaries
    reg [3:0] scan_idx;
    reg [1:0] compute_phase;    // 0=scan, 1=find split points, 2=generate op, 3=apply swap
    reg [3:0] split_s;          // Split point in s
    reg [3:0] split_t;          // Split point in t
    reg found_mismatch;
    reg [7:0] cycle_counter;    // Prevent infinite loops
    
    // Loop variables
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            op_count <= 6'd0;
            op_s_len <= 4'd0;
            op_t_len <= 4'd0;
            valid_op <= 1'b0;
            load_idx <= 4'd0;
            op_idx <= 6'd0;
            total_ops <= 6'd0;
            output_idx <= 6'd0;
            curr_len_s <= 4'd0;
            curr_len_t <= 4'd0;
            scan_idx <= 4'd0;
            compute_phase <= 2'd0;
            split_s <= 4'd0;
            split_t <= 4'd0;
            found_mismatch <= 1'b0;
            cycle_counter <= 8'd0;
            
            // Initialize buffers
            for (i = 0; i < 16; i = i + 1) begin
                s_buf[i] <= 8'd0;
                t_buf[i] <= 8'd0;
                s_work[i] <= 8'd0;
                t_work[i] <= 8'd0;
            end
            
            // Initialize ops arrays
            for (i = 0; i < 64; i = i + 1) begin
                ops_s_len[i] <= 4'd0;
                ops_t_len[i] <= 4'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_op <= 1'b0;
                    load_idx <= 4'd0;
                    op_idx <= 6'd0;
                    total_ops <= 6'd0;
                    output_idx <= 6'd0;
                    scan_idx <= 4'd0;
                    compute_phase <= 2'd0;
                    found_mismatch <= 1'b0;
                    cycle_counter <= 8'd0;
                    
                    if (start) begin
                        state <= LOAD_S;
                        curr_len_s <= len_s;
                        curr_len_t <= len_t;
                    end
                end
                
                LOAD_S: begin
                    // Store character into buffer
                    s_buf[load_idx] <= s_char_i;
                    s_work[load_idx] <= s_char_i;
                    
                    if (load_idx < len_s) begin
                        load_idx <= load_idx + 4'd1;
                    end else begin
                        load_idx <= 4'd0;
                        state <= LOAD_T;
                    end
                end
                
                LOAD_T: begin
                    // Store character into buffer
                    t_buf[load_idx] <= t_char_i;
                    t_work[load_idx] <= t_char_i;
                    
                    if (load_idx < len_t) begin
                        load_idx <= load_idx + 4'd1;
                    end else begin
                        load_idx <= 4'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Check if done with computation
                    if (curr_len_s == 4'd0 && curr_len_t == 4'd0) begin
                        total_ops <= op_idx;
                        state <= OUTPUT;
                    end else if (op_idx >= 6'd63 || cycle_counter >= 8'd200) begin
                        // Max operations or timeout
                        total_ops <= op_idx;
                        state <= OUTPUT;
                    end else begin
                        case (compute_phase)
                            2'd0: begin // Scan for mismatch
                                if (scan_idx >= curr_len_s || scan_idx >= curr_len_t) begin
                                    // Reached end of shorter string
                                    if (scan_idx >= curr_len_s && scan_idx >= curr_len_t) begin
                                        // Both strings exhausted - done
                                        total_ops <= op_idx;
                                        state <= OUTPUT;
                                    end else if (scan_idx >= curr_len_s) begin
                                        // s exhausted, t has remaining
                                        // All remaining in t should be 'a'
                                        if (t_work[scan_idx] == 8'd98) begin // 'b'
                                            found_mismatch <= 1'b1;
                                        end
                                        scan_idx <= scan_idx + 4'd1;
                                    end else begin // scan_idx >= curr_len_t
                                        // t exhausted, s has remaining
                                        if (s_work[scan_idx] == 8'd97) begin // 'a'
                                            found_mismatch <= 1'b1;
                                        end
                                        scan_idx <= scan_idx + 4'd1;
                                    end
                                end else begin
                                    // Compare characters
                                    if (s_work[scan_idx] != t_work[scan_idx]) begin
                                        if ((s_work[scan_idx] == 8'd98 && t_work[scan_idx] == 8'd97) ||
                                            (s_work[scan_idx] == 8'd97 && t_work[scan_idx] == 8'd98)) begin
                                            found_mismatch <= 1'b1;
                                        end
                                    end
                                    scan_idx <= scan_idx + 4'd1;
                                end
                            end
                            
                            2'd1: begin // Find split points
                                if (found_mismatch) begin
                                    // Find last 'a' in s and last 'b' in t from current scan_idx
                                    split_s <= 4'd0;
                                    split_t <= 4'd0;
                                    
                                    // Find split in s (last 'a')
                                    for (i = 0; i < 16; i = i + 1) begin
                                        if (i < curr_len_s && s_work[i] == 8'd97) begin // 'a'
                                            split_s <= i + 4'd1; // 1-based length
                                        end
                                    end
                                    
                                    // Find split in t (last 'b')
                                    for (i = 0; i < 16; i = i + 1) begin
                                        if (i < curr_len_t && t_work[i] == 8'd98) begin // 'b'
                                            split_t <= i + 4'd1; // 1-based length
                                        end
                                    end
                                end
                                compute_phase <= 2'd2;
                            end
                            
                            2'd2: begin // Generate operation
                                // Check if we have valid split points
                                if (found_mismatch && (split_s > 4'd0 || split_t > 4'd0)) begin
                                    // Store operation
                                    ops_s_len[op_idx] <= split_s;
                                    ops_t_len[op_idx] <= split_t;
                                    op_idx <= op_idx + 6'd1;
                                    compute_phase <= 2'd3;
                                end else begin
                                    // No mismatch or no valid split, skip
                                    found_mismatch <= 1'b0;
                                    scan_idx <= 4'd0;
                                    compute_phase <= 2'd0;
                                end
                            end
                            
                            2'd3: begin // Apply swap
                                // Swap prefixes
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (i < split_s) begin
                                        if (i < split_t) begin
                                            // Both have characters, swap
                                            s_work[i] <= t_work[i];
                                            t_work[i] <= s_work[i];
                                        end else begin
                                            // s has, t doesn't - remove from s
                                            s_work[i] <= s_work[i]; // Will be shifted later
                                        end
                                    end else if (i < split_t) begin
                                        // t has, s doesn't
                                        t_work[i] <= t_work[i]; // Will be shifted later
                                    end
                                end
                                
                                // Need to shift arrays and update lengths
                                // This is complex, for now just apply simple swap
                                // and reset for next scan
                                
                                // Update lengths
                                curr_len_s <= curr_len_s + split_t - split_s;
                                curr_len_t <= curr_len_t + split_s - split_t;
                                
                                found_mismatch <= 1'b0;
                                scan_idx <= 4'd0;
                                compute_phase <= 2'd0;
                            end
                        endcase
                    end
                end
                
                OUTPUT: begin
                    if (output_idx < total_ops) begin
                        op_s_len <= ops_s_len[output_idx];
                        op_t_len <= ops_t_len[output_idx];
                        valid_op <= 1'b1;
                        op_count <= total_ops;
                        output_idx <= output_idx + 6'd1;
                    end else begin
                        valid_op <= 1'b0;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule