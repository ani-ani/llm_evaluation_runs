module expected_score_calculator(
    input clk,
    input rst_n,
    input start,
    input data_valid,
    input data_last,
    input [7:0] data_in,
    output reg [15:0] result,
    output reg done
);
    
    // Main States
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] PARSE_INPUT = 3'd1;
    localparam [2:0] BUILD_TRIE  = 3'd2;
    localparam [2:0] COMPUTE_DP  = 3'd3;
    localparam [2:0] DONE_STATE  = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Input Parsing Registers
    reg [7:0] total_time;
    reg [7:0] num_questions;
    reg [3:0] question_count;
    reg [2:0] word_len;
    reg [1:0] byte_count;
    reg [7:0] word_id_count;
    
    // Trie Node Structure (Max 32 nodes)
    reg [7:0] trie_child [0:31][0:15];  // 32 nodes × 16 children
    reg [7:0] trie_count [0:31];        // Node question counts
    reg [4:0] current_node;
    reg [4:0] node_count;
    
    // DP Computation Registers
    reg [7:0] t_counter;
    reg [4:0] node_index;
    reg [15:0] dp_table [0:31][0:8];   // 32 nodes × 9 time steps
    
    // Fixed-point arithmetic (Q8.8)
    reg [15:0] k_inv_lut[1:8];  // 1/k values in Q8.8
    
    // Synchronization Registers
    reg parse_complete;
    reg trie_complete;
    reg dp_complete;
    reg [7:0] cycle_counter;
    
    integer i, j;
    
    // Initialize LUT on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            k_inv_lut[1] <= 16'h0100;  // 1/1 = 1.0
            k_inv_lut[2] <= 16'h0080;  // 1/2 = 0.5
            k_inv_lut[3] <= 16'h0055;  // ~1/3 ≈ 0.333
            k_inv_lut[4] <= 16'h0040;  // 1/4 = 0.25
            k_inv_lut[5] <= 16'h0033;  // ~1/5 ≈ 0.2
            k_inv_lut[6] <= 16'h002A;  // ~1/6 ≈ 0.166
            k_inv_lut[7] <= 16'h0024;  // ~1/7 ≈ 0.142
            k_inv_lut[8] <= 16'h0020;  // 1/8 = 0.125
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            total_time <= 8'd0;
            num_questions <= 8'd0;
            question_count <= 4'd0;
            word_len <= 3'd0;
            byte_count <= 2'd0;
            word_id_count <= 8'd0;
            current_node <= 5'd0;
            node_count <= 5'd0;
            parse_complete <= 1'b0;
            trie_complete <= 1'b0;
            dp_complete <= 1'b0;
            cycle_counter <= 8'd0;
            
            for (i = 0; i < 32; i = i + 1) begin
                trie_count[i] <= 8'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    trie_child[i][j] <= 8'd0;
                end
                
                for (j = 0; j <= 8; j = j + 1) begin
                    dp_table[i][j] <= 16'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    parse_complete <= 1'b0;
                    trie_complete <= 1'b0;
                    dp_complete <= 1'b0;
                    
                    if (start) begin
                        state <= PARSE_INPUT;
                    end
                end
                
                PARSE_INPUT: begin
                    if (data_valid) begin
                        if (cycle_counter == 8'd0) begin
                            total_time <= data_in;
                        end else if(cycle_counter == 8'd1) begin
                            num_questions <= data_in;
                        end else if(byte_count == 2'd0) begin
                            word_len <= data_in[2:0];
                            byte_count <= byte_count + 1;
                        end else if(word_id_count < word_len) begin
                            // Store word ID for current question
                            // (Actual trie construction happens in BUILD_TRIE)
                            word_id_count <= word_id_count + 1;
                        end else begin
                            // Skip answer byte and reset counters
                            question_count <= question_count + 1;
                            word_id_count <= 8'd0;
                            byte_count <= 2'd0;
                        end
                        
                        if (data_last) begin
                            parse_complete <= 1'b1;
                            state <= BUILD_TRIE;
                        end
                        
                        cycle_counter <= cycle_counter + 1;
                    end
                end
                
                BUILD_TRIE: begin
                    // Simplified trie building logic
                    // (Implementation details omitted for brevity)
                    trie_complete <= 1'b1;
                    state <= COMPUTE_DP;
                end
                
                COMPUTE_DP: begin
                    // Time steps
                    for (t_counter = 1; t_counter <= total_time; t_counter = t_counter + 1) begin
                        // Node traversal
                        for (node_index = 0; node_index < node_count; node_index = node_index + 1) begin
                            // Implementation of DP recurrence
                            // (Fixed-point arithmetic implementation here)
                            
                            // Placeholder result for demonstration
                            dp_table[node_index][t_counter] <= dp_table[node_index][t_counter - 1] + 16'h0001;
                        end
                    end
                    
                    // Store root node result
                    result <= dp_table[0][total_time];
                    dp_complete <= 1'b1;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        if (state == IDLE && start) next_state = PARSE_INPUT;
        if (parse_complete) next_state = BUILD_TRIE;
        if (trie_complete) next_state = COMPUTE_DP;
        if (dp_complete) next_state = DONE_STATE;
    end
    
endmodule