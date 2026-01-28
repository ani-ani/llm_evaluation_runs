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
localparam [2:0] IDLE = 3'b000;
localparam [2:0] FETCH = 3'b001;
localparam [2:0] FIND_X = 3'b010;
localparam [2:0] FIND_Y = 3'b011;
localparam [2:0] CHECK = 3'b100;
localparam [2:0] UPDATE = 3'b101;
localparam [2:0] DONE = 3'b110;

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
    begin
        find_root = x;
        for (i=0; i<MAX_WORDS; i=i+1) begin
            if (parent[find_root] != find_root)
                find_root = parent[find_root];
        end
    end
endfunction

// Combinational logic for roots
wire [2:0] root_x_wire = find_root(current_word1);
wire [2:0] root_y_wire = find_root(current_word2);

// Combinational contradiction check for "is"
wire contradiction_is_wire;
wire [MAX_WORDS-1:0] set_x_mask;
wire [MAX_WORDS-1:0] set_y_mask;
generate
    genvar i, j;
    for (i=0; i<MAX_WORDS; i=i+1) begin : set_x
        assign set_x_mask[i] = (parent[i] == root_x_reg);
    end
    for (j=0; j<MAX_WORDS; j=j+1) begin : set_y
        assign set_y_mask[j] = (parent[j] == root_y_reg);
    end
    wire [MAX_WORDS-1:0] conflict_x;
    for (i=0; i<MAX_WORDS; i=i+1) begin : check_conflicts
        assign conflict_x[i] = set_x_mask[i] & (|(set_y_mask & not_matrix[i]));
    end
    assign contradiction_is_wire = |conflict_x;
endgenerate

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        ready <= 0;
        done <= 0;
        result <= 0;
        contradiction_found <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    for (integer i=0; i<MAX_WORDS; i=i+1) begin
                        parent[i] <= i;
                        not_matrix[i] <= 0;
                    end
                    contradiction_found <= 0;
                    ready <= 1;
                    done <= 0;
                    result <= 0;
                    state <= FETCH;
                end
            end

            FETCH: begin
                if (statement_valid) begin
                    current_type <= statement_type;
                    current_word1 <= word1;
                    current_word2 <= word2;
                    current_last <= last;
                    ready <= 0;
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
                if (current_type == 0) begin
                    if (contradiction_is_wire)
                        contradiction_found <= 1;
                end else begin
                    if (root_x_reg == root_y_reg)
                        contradiction_found <= 1;
                end
                state <= UPDATE;
            end

            UPDATE: begin
                if (contradiction_found == 0) begin
                    if (current_type == 0)
                        parent[root_x_reg] <= root_y_reg;
                    else begin
                        not_matrix[current_word1][current_word2] <= 1;
                        not_matrix[current_word2][current_word1] <= 1;
                    end
                end

                if (current_last) begin
                    state <= DONE;
                end else begin
                    ready <= 1;
                    state <= FETCH;
                end
            end

            DONE: begin
                done <= 1;
                result <= ~contradiction_found;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule