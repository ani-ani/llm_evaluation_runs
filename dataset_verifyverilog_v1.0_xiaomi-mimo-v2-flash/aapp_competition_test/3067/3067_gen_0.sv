module best_solution_sequence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] seq_data_0,  // Sequence 0, 16 elements
    input wire [127:0] seq_data_1,  // Sequence 1
    input wire [127:0] seq_data_2,  // Sequence 2
    input wire [127:0] seq_data_3,  // Sequence 3
    input wire [127:0] seq_data_4,  // Sequence 4
    input wire [127:0] seq_data_5,  // Sequence 5
    input wire [127:0] seq_data_6,  // Sequence 6
    input wire [127:0] seq_data_7,  // Sequence 7
    input wire [31:0] seq_lens,     // 8 sequences × 4-bit lengths
    input wire [7:0] total_len,
    output reg [7:0] out_val,
    output reg out_valid,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE     = 4'd0;
    localparam [3:0] INIT     = 4'd1;
    localparam [3:0] COMPARE  = 4'd2;
    localparam [3:0] OUTPUT   = 4'd3;
    localparam [3:0] DONE     = 4'd4;
    localparam [3:0] LOOKAHEAD = 4'd5;
    
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers
    reg [2:0] ptr[0:7];          // Current pointer for each sequence
    reg [2:0] best_seq;          // Best sequence index
    reg [2:0] comp_seq;          // Comparison sequence index
    reg [7:0] out_count;         // Output counter
    reg [3:0] lookahead_depth;   // How deep to look ahead
    reg [7:0] current_val;       // Value of best sequence
    reg [7:0] compare_val;       // Value of comparison sequence
    
    // Decoded lengths
    wire [2:0] len[0:7];
    assign len[0] = seq_lens[3:0];
    assign len[1] = seq_lens[7:4];
    assign len[2] = seq_lens[11:8];
    assign len[3] = seq_lens[15:12];
    assign len[4] = seq_lens[19:16];
    assign len[5] = seq_lens[23:20];
    assign len[6] = seq_lens[27:24];
    assign len[7] = seq_lens[31:28];
    
    // Helper to extract value from sequence at given index
    function [7:0] get_val;
        input [2:0] seq_idx;
        input [2:0] elem_idx;
        reg [7:0] val;
        begin
            case (seq_idx)
                3'd0: val = seq_data_0[elem_idx*8 +: 8];
                3'd1: val = seq_data_1[elem_idx*8 +: 8];
                3'd2: val = seq_data_2[elem_idx*8 +: 8];
                3'd3: val = seq_data_3[elem_idx*8 +: 8];
                3'd4: val = seq_data_4[elem_idx*8 +: 8];
                3'd5: val = seq_data_5[elem_idx*8 +: 8];
                3'd6: val = seq_data_6[elem_idx*8 +: 8];
                3'd7: val = seq_data_7[elem_idx*8 +: 8];
                default: val = 8'd0;
            endcase
            get_val = val;
        end
    endfunction
    
    // Combinational comparison logic for current pointers
    wire [7:0] curr_best_val;
    wire [7:0] curr_comp_val;
    wire curr_best_valid;
    wire curr_comp_valid;
    
    assign curr_best_val = (best_seq < 8'd8) ? get_val(best_seq, ptr[best_seq]) : 8'd0;
    assign curr_comp_val = (comp_seq < 8'd8) ? get_val(comp_seq, ptr[comp_seq]) : 8'd0;
    assign curr_best_valid = (best_seq < 8'd8) && (ptr[best_seq] < len[best_seq]);
    assign curr_comp_valid = (comp_seq < 8'd8) && (ptr[comp_seq] < len[comp_seq]);
    
    // Lookahead comparison
    reg [7:0] best_lookahead[0:7];
    reg [7:0] comp_lookahead[0:7];
    reg [3:0] lb, lc;
    reg lookahead_done;
    reg best_wins;
    reg comp_wins;
    
    always @(*) begin
        // Initialize lookaheads
        for (lb = 0; lb < 8; lb = lb + 1) begin
            best_lookahead[lb] = 8'd0;
            comp_lookahead[lb] = 8'd0;
        end
        
        // Default: best stays if both valid, otherwise fill
        lookahead_done = 1'b0;
        best_wins = 1'b0;
        comp_wins = 1'b0;
        
        if (!curr_best_valid && !curr_comp_valid) begin
            lookahead_done = 1'b1;
            best_wins = 1'b0;
            comp_wins = 1'b0;
        end else if (!curr_best_valid && curr_comp_valid) begin
            lookahead_done = 1'b1;
            best_wins = 1'b0;
            comp_wins = 1'b1;
        end else if (curr_best_valid && !curr_comp_valid) begin
            lookahead_done = 1'b1;
            best_wins = 1'b1;
            comp_wins = 1'b0;
        end else if (curr_best_val != curr_comp_val) begin
            lookahead_done = 1'b1;
            best_wins = (curr_best_val < curr_comp_val);
            comp_wins = (curr_comp_val < curr_best_val);
        end else begin
            // Equal values, need to look ahead
            // Check lookahead_depth + 1 elements
            for (lc = 0; lc < lookahead_depth + 1 && !lookahead_done; lc = lc + 1) begin
                // Get lookahead values
                reg [2:0] best_look_idx;
                reg [2:0] comp_look_idx;
                reg [7:0] best_look_val;
                reg [7:0] comp_look_val;
                reg best_look_valid;
                reg comp_look_valid;
                
                best_look_idx = ptr[best_seq] + lc;
                comp_look_idx = ptr[comp_seq] + lc;
                
                best_look_valid = (best_look_idx < len[best_seq]);
                comp_look_valid = (comp_look_idx < len[comp_seq]);
                
                if (!best_look_valid && !comp_look_valid) begin
                    lookahead_done = 1'b1;
                    best_wins = 1'b0;
                    comp_wins = 1'b0;
                end else if (!best_look_valid && comp_look_valid) begin
                    lookahead_done = 1'b1;
                    best_wins = 1'b0;
                    comp_wins = 1'b1;
                end else if (best_look_valid && !comp_look_valid) begin
                    lookahead_done = 1'b1;
                    best_wins = 1'b1;
                    comp_wins = 1'b0;
                end else begin
                    best_look_val = get_val(best_seq, best_look_idx);
                    comp_look_val = get_val(comp_seq, comp_look_idx);
                    
                    if (best_look_val != comp_look_val) begin
                        lookahead_done = 1'b1;
                        best_wins = (best_look_val < comp_look_val);
                        comp_wins = (comp_look_val < best_look_val);
                    end
                end
            end
            
            if (!lookahead_done) begin
                // All equal up to lookahead_depth
                // Prefer shorter sequence
                best_wins = (len[best_seq] <= len[comp_seq]);
                comp_wins = (len[comp_seq] < len[best_seq]);
                lookahead_done = 1'b1;
            end
        end
    end
    
    // FSM next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            
            INIT: begin
                next_state = COMPARE;
            end
            
            COMPARE: begin
                if (lookahead_done) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = LOOKAHEAD;
                end
            end
            
            LOOKAHEAD: begin
                if (lookahead_done) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = LOOKAHEAD;
                end
            end
            
            OUTPUT: begin
                if (out_count == total_len) begin
                    next_state = DONE;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_val <= 8'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
            out_count <= 8'd0;
            best_seq <= 3'd0;
            comp_seq <= 3'd0;
            lookahead_depth <= 4'd0;
            current_val <= 8'd0;
            compare_val <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                ptr[i] <= 3'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    out_count <= 8'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        ptr[i] <= 3'd0;
                    end
                end
                
                INIT: begin
                    // Find first available sequence
                    best_seq <= 3'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (len[i] > 0 && ptr[i] < len[i]) begin
                            best_seq <= i;
                        end
                    end
                    comp_seq <= 3'd1;
                    lookahead_depth <= 4'd4;  // Look ahead up to 4 elements
                end
                
                COMPARE: begin
                    if (lookahead_done) begin
                        if (best_wins) begin
                            // Keep best_seq
                        end else if (comp_wins) begin
                            best_seq <= comp_seq;
                        end
                        // Move to next comparison if not done
                        if (comp_seq < 3'd7) begin
                            comp_seq <= comp_seq + 3'd1;
                        end
                    end
                end
                
                LOOKAHEAD: begin
                    // Already handled in combinational block
                    // Increment lookahead depth if still going
                    if (!lookahead_done) begin
                        if (lookahead_depth < 4'd10) begin
                            lookahead_depth <= lookahead_depth + 4'd1;
                        end
                    end
                end
                
                OUTPUT: begin
                    out_valid <= 1'b1;
                    out_count <= out_count + 8'd1;
                    
                    // Output current best value
                    out_val <= get_val(best_seq, ptr[best_seq]);
                    
                    // Advance pointer
                    ptr[best_seq] <= ptr[best_seq] + 3'd1;
                    
                    // Reset for next comparison
                    comp_seq <= 3'd0;
                    lookahead_depth <= 4'd4;
                end
                
                DONE: begin
                    done <= 1'b1;
                    out_valid <= 1'b0;
                    out_val <= 8'd0;
                end
            endcase
            
            // Handle done pulse timing
            if (state == OUTPUT && out_count == total_len && next_state == DONE) begin
                done <= 1'b1;
            end else if (state == DONE) begin
                done <= 1'b0;
            end
        end
    end
    
endmodule