module substring_search(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a [0:7],
    input wire [7:0] b [0:7],
    input wire [2:0] n,
    input wire [2:0] m,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CHECK    = 3'd1;
    localparam [2:0] COMPARE  = 3'd2;
    localparam [2:0] NEXT_POS = 3'd3;
    localparam [2:0] MATCH    = 3'd4;
    localparam [2:0] DONE     = 3'd5;
    localparam [2:0] NO_MATCH = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] pos_reg;          // Current start position in A
    reg [2:0] i_reg;            // Current index in B
    reg [7:0] cycle_count;      // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Wires for combinational logic
    wire [2:0] pos_plus_i;
    wire pos_plus_i_valid;
    wire pos_plus_m_valid;
    wire a_element_valid;
    wire b_element_valid;
    wire match;
    wire full_match;
    wire exceed_limit;

    // Combinational calculations
    assign pos_plus_i = pos_reg + i_reg;
    assign pos_plus_m_valid = (pos_reg + m) <= n;
    assign a_element_valid = pos_plus_i <= n;
    assign b_element_valid = i_reg < m;
    assign full_match = (i_reg == m);
    assign exceed_limit = !pos_plus_m_valid;
    
    // Element comparison
    assign match = (a_element_valid && b_element_valid && 
                    a[pos_plus_i] == b[i_reg]);

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                end
            end
            CHECK: begin
                if (exceed_limit) begin
                    next_state = NO_MATCH;
                end else if (full_match) begin
                    next_state = MATCH;
                end else begin
                    next_state = COMPARE;
                end
            end
            COMPARE: begin
                if (match) begin
                    if (full_match) begin
                        next_state = MATCH;
                    end else begin
                        next_state = COMPARE;
                    end
                end else begin
                    next_state = NEXT_POS;
                end
            end
            NEXT_POS: begin
                if (exceed_limit) begin
                    next_state = NO_MATCH;
                end else begin
                    next_state = COMPARE;
                end
            end
            MATCH: begin
                next_state = DONE;
            end
            NO_MATCH: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos_reg <= 3'd0;
            i_reg <= 3'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        pos_reg <= 3'd0;
                        i_reg <= 3'd0;
                    end
                end
                CHECK: begin
                    // Already calculated in wires
                end
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (match) begin
                        i_reg <= i_reg + 3'd1;
                    end
                end
                NEXT_POS: begin
                    pos_reg <= pos_reg + 3'd1;
                    i_reg <= 3'd0;
                end
                MATCH: begin
                    result <= 1'b1;
                    done <= 1'b1;
                end
                NO_MATCH: begin
                    result <= 1'b0;
                    done <= 1'b1;
                end
                DONE: begin
                    done <= 1'b0;
                end
                default: begin
                    pos_reg <= 3'd0;
                    i_reg <= 3'd0;
                    result <= 1'b0;
                end
            endcase
        end
    end

endmodule