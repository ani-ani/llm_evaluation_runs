module AlphabetSolver(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [7:0] words [0:3][0:7],  // [MAX_WORDS][MAX_WORD_LEN]
    input [3:0] word_lengths [0:3], // [MAX_WORDS]
    output reg [7:0] result_order [0:4],
    output reg [1:0] status,
    output reg done
);

localparam ALPHABET_SIZE = 5;
localparam MAX_WORDS = 4;
localparam MAX_WORD_LEN = 8;

// State definitions
localparam [3:0] 
    IDLE             = 4'd0,
    CHECK_PREFIX     = 4'd1,
    FIND_DIFF        = 4'd2,
    ADD_EDGE         = 4'd3,
    TOPO_INIT        = 4'd4,
    TOPO_LOOP        = 4'd5,
    FIND_ZERO_IN_DEGREE = 4'd6,
    UPDATE_GRAPH     = 4'd7,
    DONE_STATE       = 4'd8;

reg [3:0] state, next_state;
reg [4:0] edge_matrix[0:4][0:4];  // ALPHABET_SIZE x ALPHABET_SIZE
reg [4:0] in_degree[0:4];         // ALPHABET_SIZE
reg [4:0] queue[0:4];             // Kahn's algorithm
reg [2:0] current_pair;           // Current word pair (0 to N-2)
reg [3:0] char_pos;               // Current character position
reg [3:0] topo_step;              // Topological sort step
reg [2:0] node_count;             // Zero in-degree node count
reg [2:0] zero_node;              // Node with zero in-degree
reg [9:0] cycle_counter;          // Safety timeout

// Helper regs
reg [7:0] char_curr, char_next;
reg [3:0] len_curr, len_next;
reg flg_valid_order;
reg flg_ambig;
integer i, j; // Loop counters

// ASCII to index conversion
function [4:0] char_to_index;
    input [7:0] c;
    char_to_index = c - 8'd97; // 'a'=97 maps to 0
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        status <= 2'b00;
        cycle_counter <= 10'd0;
        
        // Initialize result_order array
        for (i = 0; i < ALPHABET_SIZE; i = i + 1)
            result_order[i] <= 8'd0;
            
        // Initialize edge_matrix array
        for (i = 0; i < ALPHABET_SIZE; i = i + 1) begin
            for (j = 0; j < ALPHABET_SIZE; j = j + 1) begin
                edge_matrix[i][j] <= 1'b0;
            end
        end
        
        // Initialize in_degree array
        for (i = 0; i < ALPHABET_SIZE; i = i + 1)
            in_degree[i] <= 5'd0;
        
    end else begin
        state <= next_state;
        cycle_counter <= cycle_counter + 10'd1;
        
        if (state != IDLE) begin
            if (cycle_counter >= 10'd900) begin
                state <= DONE_STATE;
                status <= 2'b00; // Timeout = IMPOSSIBLE
            end
        end
    end
end

always @(*) begin
    next_state = state;
    
    case (state)
        IDLE: begin
            if (start) next_state = CHECK_PREFIX;
        end
        
        CHECK_PREFIX: begin
            if (current_pair >= N - 4'd1) begin
                next_state = TOPO_INIT;
            end else begin
                len_curr = word_lengths[current_pair];
                len_next = word_lengths[current_pair+1];
                
                if (len_curr > len_next && 
                    words[current_pair][len_next-4'd1] == words[current_pair+1][len_next-4'd1]) begin 
                    next_state = DONE_STATE; // Invalid prefix
                end else begin
                    next_state = FIND_DIFF;
                end
            end
        end
        
        FIND_DIFF: begin
            char_curr = words[current_pair][char_pos];
            char_next = words[current_pair+1][char_pos];
            
            if (char_pos >= len_curr || char_pos >= len_next)
                next_state = CHECK_PREFIX;
            else if (char_curr != char_next)
                next_state = ADD_EDGE;
            else
                next_state = FIND_DIFF; // Increment char_pos
        end
        
        ADD_EDGE: begin
            // Add edge only if not already present
            next_state = CHECK_PREFIX;
        end
        
        TOPO_INIT: begin
            // Initialize in_degree from edge_matrix
            next_state = TOPO_LOOP;
        end
        
        TOPO_LOOP: begin
            if (topo_step >= ALPHABET_SIZE)
                next_state = DONE_STATE;
            else if (node_count > 1)
                next_state = DONE_STATE; // Ambiguous
            else if (node_count == 0)
                next_state = DONE_STATE; // Cycle detected
            else
                next_state = UPDATE_GRAPH;
        end
        
        FIND_ZERO_IN_DEGREE: begin
            next_state = TOPO_LOOP;
        end
        
        UPDATE_GRAPH: begin
            next_state = FIND_ZERO_IN_DEGREE;
        end
        
        DONE_STATE: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Sequential logic for processing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_pair <= 3'd0;
        char_pos <= 4'd0;
        topo_step <= 4'd0;
        node_count <= 3'd0;
        zero_node <= 3'd0;
        flg_valid_order <= 1'b0;
        flg_ambig <= 1'b0;
        
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                status <= 2'b00;
                current_pair <= 3'd0;
                flg_valid_order <= 1'b0;
                flg_ambig <= 1'b0;
                
                // Clear edge_matrix
                for (i = 0; i < ALPHABET_SIZE; i = i + 1) begin
                    for (j = 0; j < ALPHABET_SIZE; j = j + 1) begin
                        edge_matrix[i][j] <= 1'b0;
                    end
                end
                cycle_counter <= 10'd0;
            end
            
            CHECK_PREFIX: begin
                if (current_pair >= N - 4'd1) begin
                    current_pair <= 3'd0;
                end else begin
                    char_pos <= 4'd0;
                end
            end
            
            FIND_DIFF: begin
                char_pos <= char_pos + 4'd1;
            end
            
            ADD_EDGE: begin
                if (char_curr != char_next) begin
                    let i_src = char_to_index(char_curr);
                    let i_dst = char_to_index(char_next);
                    
                    if (!edge_matrix[i_src][i_dst]) begin
                        edge_matrix[i_src][i_dst] <= 1'b1;
                    end
                end
                current_pair <= current_pair + 3'd1;
            end
            
            TOPO_INIT: begin
                // Calculate initial in_degrees
                for (i = 0; i < ALPHABET_SIZE; i = i + 1) begin
                    in_degree[i] <= 5'd0;
                    for (j = 0; j < ALPHABET_SIZE; j = j + 1) begin
                        if (edge_matrix[j][i])
                            in_degree[i] <= in_degree[i] + 5'd1;
                    end
                end
                topo_step <= 4'd0;
            end
            
            FIND_ZERO_IN_DEGREE: begin
                node_count <= 3'd0;
                zero_node <= 3'd0;
                
                for (i = 0; i < ALPHABET_SIZE; i = i + 1) begin
                    if (in_degree[i] == 5'd0) begin
                        node_count <= node_count + 3'd1;
                        zero_node <= i;
                    end
                end
            end
            
            TOPO_LOOP: begin
                if (node_count == 1) begin
                    // Record result
                    result_order[topo_step] <= zero_node + 8'd97; // Convert to ASCII
                    flg_valid_order <= (topo_step == ALPHABET_SIZE - 4'd1);
                    topo_step <= topo_step + 4'd1;
                end else if (node_count == 0) begin
                    status <= 2'b00; // IMPOSSIBLE (cycle)
                end else begin
                    flg_ambig <= 1'b1;
                    status <= 2'b01; // AMBIGUOUS
                end
            end
            
            UPDATE_GRAPH: begin
                in_degree[zero_node] <= 5'd0;
                
                // Decrement neighbors' in_degrees
                for (j = 0; j < ALPHABET_SIZE; j = j + 1) begin
                    if (edge_matrix[zero_node][j])
                        in_degree[j] <= in_degree[j] - 5'd1;
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                
                if (flg_valid_order && !flg_ambig)
                    status <= 2'b10; // UNIQUE
                else if (flg_ambig)
                    status <= 2'b01; // AMBIGUOUS
                else
                    status <= 2'b00; // IMPOSSIBLE
            end
        endcase
    end
end

endmodule