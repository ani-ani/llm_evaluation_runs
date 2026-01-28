module swap_pairs_generator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    output reg [2:0] pair_a,
    output reg [2:0] pair_b,
    output reg valid,
    output reg done,
    output reg possible
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] GENERATE  = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Counters for pair generation
    reg [2:0] i_reg, j_reg;
    reg [2:0] i_next, j_next;

    // Check if n is valid (n <= 8 and n % 4 == 0 or n % 4 == 1)
    wire valid_n = (n <= 3'd8) && ((n[1:0] == 2'd0) || (n[1:0] == 2'd1));

    // Maximum pairs calculation: n*(n-1)/2
    reg [4:0] max_pairs;
    reg [4:0] pair_count;

    // Compute max_pairs based on n
    always @(*) begin
        case (n)
            3'd0: max_pairs = 5'd0;
            3'd1: max_pairs = 5'd0;
            3'd2: max_pairs = 5'd1;
            3'd3: max_pairs = 5'd3;
            3'd4: max_pairs = 5'd6;
            3'd5: max_pairs = 5'd10;
            3'd6: max_pairs = 5'd15;
            3'd7: max_pairs = 5'd21;
            3'd8: max_pairs = 5'd28;
            default: max_pairs = 5'd0;
        endcase
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            pair_count <= 5'd0;
            pair_a <= 3'd0;
            pair_b <= 3'd0;
            valid <= 1'b0;
            done <= 1'b0;
            possible <= 1'b1;
        end else begin
            state <= next_state;
            i_reg <= i_next;
            j_reg <= j_next;
            pair_count <= pair_count + 5'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        i_next = i_reg;
        j_next = j_reg;
        valid = 1'b0;
        done = 1'b0;
        possible = valid_n;
        pair_a = 3'd0;
        pair_b = 3'd0;

        case (state)
            IDLE: begin
                if (start) begin
                    if (valid_n) begin
                        next_state = GENERATE;
                        i_next = 3'd0;
                        j_next = 3'd1;
                        pair_count = 5'd0;
                    end else begin
                        next_state = DONE_STATE;
                        done = 1'b1;
                        possible = 1'b0;
                    end
                end
            end

            GENERATE: begin
                if (pair_count < max_pairs) begin
                    // Generate current pair
                    pair_a = i_reg;
                    pair_b = j_reg;
                    valid = 1'b1;

                    // Calculate next pair
                    if (j_reg + 3'd1 < n) begin
                        i_next = i_reg;
                        j_next = j_reg + 3'd1;
                    end else begin
                        i_next = i_reg + 3'd1;
                        j_next = i_next + 3'd1;
                    end
                end else begin
                    next_state = DONE_STATE;
                    done = 1'b1;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule