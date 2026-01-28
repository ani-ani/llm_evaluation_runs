module consistency_checker (
    input clk,
    input rst_n,
    input start,
    input statement_valid,
    input last,
    input statement_type,
    input [2:0] word1,
    input [2:0] word2,
    output reg ready,
    output reg done,
    output reg result
);

// Parameters
parameter MAX_WORDS = 8;

// State encoding
localparam [2:0] IDLE = 3'd0;
localparam [2:0] FETCH = 3'd1;
localparam [2:0] FIND_X = 3'd2;
localparam [2:0] FIND_Y = 3'd3;
localparam [2:0] CHECK = 3'd4;
localparam [2:0] UPDATE = 3'd5;
localparam [2:0] DONE = 3'd6;

// Registers
reg [2:0] state;
reg [2:0] parent [0:MAX_WORDS-1];
reg [MAX_WORDS-1:0] not_matrix [0:MAX_WORDS-1];
reg contradiction_found;
reg [2:0] root_x_reg, root_y_reg;
reg current_type;
reg current_last;
reg [2:0] current_word1, current_word2;

// Helper function for find
function automatic [2:0] find_root;
    input [2:0] x;
    integer i;
    reg [2:0] current;
    begin
        current = x;
        for (i = 0; i < MAX_WORDS; i = i + 1) begin
            if (parent[current] != current)
                current = parent[current];
        end
        find_root = current;
    end
endfunction

// Combinational logic for roots (wire for current state values)
wire [2:0] root_x_wire = find_root(current_word1);
wire [2:0] root_y_wire = find_root(current_word2);

// Combinational contradiction check for "is" statement
reg contradiction_is_reg;
always @(*) begin
    integer i, j;
    reg [MAX_WORDS-1:0] set_x_mask;
    reg [MAX_WORDS-1:0] set_y_mask;
    reg [MAX_WORDS-1:0] conflict_x;
    
    // Build masks for sets containing root_x and root_y
    set_x_mask = 0;
    set_y_mask = 0;
    for (i = 0; i < MAX_WORDS; i = i + 1) begin
        if (parent[i] == root_x_reg)
            set_x_mask[i] = 1'b1;
        if (parent[i] == root_y_reg)
            set_y_mask[i] = 1'b1;
    end
    
    // Check for conflicts: any element in set_x that is "not" any element in set_y
    conflict_x = 0;
    for (i = 0; i < MAX_WORDS; i = i + 1) begin
        if (set_x_mask[i]) begin
            for (j = 0; j < MAX_WORDS; j = j + 1) begin
                if (set_y_mask[j] && not_matrix[i][j]) begin
                    conflict_x[i] = 1'b1;
                end
            end
        end
    end
    
    // If any conflict exists, contradiction found
    contradiction_is_reg = |conflict_x;
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        ready <= 1'b0;
        done <= 1'b0;
        result <= 1'b0;
        contradiction_found <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    for (integer i = 0; i < MAX_WORDS; i = i + 1) begin
                        parent[i] <= i;
                        not_matrix[i] <= 0;
                    end
                    contradiction_found <= 1'b0;
                    ready <= 1'b1;
                    done <= 1'b0;
                    result <= 1'b0;
                    state <= FETCH;
                end
            end

            FETCH: begin
                if (statement_valid) begin
                    current_type <= statement_type;
                    current_word1 <= word1;
                    current_word2 <= word2;
                    current_last <= last;
                    ready <= 1'b0;
                    state <= FIND_X;
                end
            end

            FIND_X: begin
                root_x_reg <= root_x_wire;
                state <= FIND_Y;
            end

            FIND_Y: begin
                root_y_reg <= root_y_wire;
                state <= CHECK;
            end

            CHECK: begin
                if (current_type == 1'b0) begin // "is" statement
                    if (contradiction_is_reg)
                        contradiction_found <= 1'b1;
                end else begin // "not" statement
                    if (root_x_reg == root_y_reg)
                        contradiction_found <= 1'b1;
                end
                state <= UPDATE;
            end

            UPDATE: begin
                if (contradiction_found == 1'b0) begin
                    if (current_type == 1'b0)
                        parent[root_x_reg] <= root_y_reg;
                    else begin
                        not_matrix[current_word1][current_word2] <= 1'b1;
                        not_matrix[current_word2][current_word1] <= 1'b1;
                    end
                end

                if (current_last) begin
                    state <= DONE;
                end else begin
                    ready <= 1'b1;
                    state <= FETCH;
                end
            end

            DONE: begin
                done <= 1'b1;
                result <= ~contradiction_found;
                state <= IDLE; // Return to IDLE to handle next start
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule