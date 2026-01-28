module dots_and_boxes (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [11:0] edges,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] S_IDLE              = 4'd0;
    localparam [3:0] S_COMPUTE_CURRENT   = 4'd1;
    localparam [3:0] S_INIT_MASK         = 4'd2;
    localparam [3:0] S_LOOP_MASK         = 4'd3;
    localparam [3:0] S_CHECK_SUBSET      = 4'd4;
    localparam [3:0] S_RESET_ADDED       = 4'd5;
    localparam [3:0] S_LOOP_BITS         = 4'd6;
    localparam [3:0] S_ADD_EDGE          = 4'd7;
    localparam [3:0] S_NEXT_BIT          = 4'd8;
    localparam [3:0] S_CHECK_VALID       = 4'd9;
    localparam [3:0] S_NEXT_MASK         = 4'd10;
    localparam [3:0] S_DONE              = 4'd11;

    // Registers
    reg [3:0] state, next_state;
    reg [11:0] mask;
    reg [11:0] missing_edges_reg;
    reg [3:0] current_counts [0:3];
    reg [3:0] added_counts [0:3];
    reg [3:0] max_count_reg;
    reg [3:0] popcnt;
    reg [3:0] bit_index;
    reg [1:0] square_idx;
    reg [3:0] temp_sum;
    reg is_subset;
    reg is_valid;
    reg [1:0] i; // Loop index for validation

    // Combinational logic for square mapping
    // Returns 4-bit mask indicating which squares are affected by edge at bit_index
    reg [3:0] squares_affected;
    always @(*) begin
        case (bit_index)
            // Horizontal edges
            4'd0: squares_affected = 4'b0001; // Square 0 (TL)
            4'd1: squares_affected = 4'b0010; // Square 1 (TR)
            4'd2: squares_affected = 4'b0100; // Square 2 (BL)
            4'd3: squares_affected = 4'b1000; // Square 3 (BR)
            4'd4: squares_affected = 4'b0001; // Square 0 (L edge)
            4'd5: squares_affected = 4'b0010; // Square 1 (R edge)
            // Vertical edges
            4'd6: squares_affected = 4'b0100; // Square 2 (Top edge)
            4'd7: squares_affected = 4'b1000; // Square 3 (Bottom edge)
            4'd8: squares_affected = 4'b0001; // Square 0 (L edge)
            4'd9: squares_affected = 4'b0100; // Square 2 (R edge)
            4'd10: squares_affected = 4'b0010; // Square 1 (L edge)
            4'd11: squares_affected = 4'b1000; // Square 3 (R edge)
            default: squares_affected = 4'b0000;
        endcase
    end

    // Combinational check for subset validity
    always @(*) begin
        is_subset = ~(|(mask & missing_edges_reg));
    end

    // Combinational check for validity of added edges
    always @(*) begin
        is_valid = 1'b1;
        for (i = 0; i < 4; i = i + 1) begin
            if (current_counts[i] + added_counts[i] > 3'd3) begin
                is_valid = 1'b0;
            end
        end
    end

    // Next State and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            mask <= 12'd0;
            missing_edges_reg <= 12'd0;
            current_counts[0] <= 4'd0;
            current_counts[1] <= 4'd0;
            current_counts[2] <= 4'd0;
            current_counts[3] <= 4'd0;
            added_counts[0] <= 4'd0;
            added_counts[1] <= 4'd0;
            added_counts[2] <= 4'd0;
            added_counts[3] <= 4'd0;
            max_count_reg <= 4'd0;
            popcnt <= 4'd0;
            bit_index <= 4'd0;
            square_idx <= 2'd0;
            temp_sum <= 4'd0;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Latch missing edges
                        missing_edges_reg <= ~edges;
                    end
                end

                S_COMPUTE_CURRENT: begin
                    // Compute current edge counts per square
                    current_counts[0] <= 4'd0;
                    current_counts[1] <= 4'd0;
                    current_counts[2] <= 4'd0;
                    current_counts[3] <= 4'd0;
                    
                    // Square 0 edges
                    if (edges[0]) current_counts[0] <= current_counts[0] + 4'd1;
                    if (edges[4]) current_counts[0] <= current_counts[0] + 4'd1;
                    if (edges[8]) current_counts[0] <= current_counts[0] + 4'd1;
                    if (edges[6]) current_counts[0] <= current_counts[0] + 4'd1;
                    
                    // Square 1 edges
                    if (edges[1]) current_counts[1] <= current_counts[1] + 4'd1;
                    if (edges[5]) current_counts[1] <= current_counts[1] + 4'd1;
                    if (edges[10]) current_counts[1] <= current_counts[1] + 4'd1;
                    if (edges[8]) current_counts[1] <= current_counts[1] + 4'd1;
                    
                    // Square 2 edges
                    if (edges[2]) current_counts[2] <= current_counts[2] + 4'd1;
                    if (edges[4]) current_counts[2] <= current_counts[2] + 4'd1;
                    if (edges[9]) current_counts[2] <= current_counts[2] + 4'd1;
                    if (edges[6]) current_counts[2] <= current_counts[2] + 4'd1;
                    
                    // Square 3 edges
                    if (edges[3]) current_counts[3] <= current_counts[3] + 4'd1;
                    if (edges[5]) current_counts[3] <= current_counts[3] + 4'd1;
                    if (edges[11]) current_counts[3] <= current_counts[3] + 4'd1;
                    if (edges[7]) current_counts[3] <= current_counts[3] + 4'd1;
                end

                S_INIT_MASK: begin
                    mask <= 12'd0;
                    max_count_reg <= 4'd0;
                end

                S_CHECK_SUBSET: begin
                    // Logic is combinational, waiting for transition
                end

                S_RESET_ADDED: begin
                    added_counts[0] <= 4'd0;
                    added_counts[1] <= 4'd0;
                    added_counts[2] <= 4'd0;
                    added_counts[3] <= 4'd0;
                    popcnt <= 4'd0;
                    bit_index <= 4'd0;
                end

                S_ADD_EDGE: begin
                    popcnt <= popcnt + 4'd1;
                    
                    if (squares_affected[0]) added_counts[0] <= added_counts[0] + 4'd1;
                    if (squares_affected[1]) added_counts[1] <= added_counts[1] + 4'd1;
                    if (squares_affected[2]) added_counts[2] <= added_counts[2] + 4'd1;
                    if (squares_affected[3]) added_counts[3] <= added_counts[3] + 4'd1;
                end

                S_NEXT_BIT: begin
                    bit_index <= bit_index + 4'd1;
                end

                S_CHECK_VALID: begin
                    // Logic is combinational, waiting for transition
                    if (is_valid && (popcnt > max_count_reg)) begin
                        max_count_reg <= popcnt;
                    end
                end

                S_NEXT_MASK: begin
                    mask <= mask + 12'd1;
                end

                S_DONE: begin
                    result <= max_count_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            S_IDLE: begin
                if (start) next_state = S_COMPUTE_CURRENT;
                else next_state = S_IDLE;
            end

            S_COMPUTE_CURRENT: begin
                next_state = S_INIT_MASK;
            end

            S_INIT_MASK: begin
                next_state = S_LOOP_MASK;
            end

            S_LOOP_MASK: begin
                if (mask == 12'd4095) next_state = S_DONE;
                else next_state = S_CHECK_SUBSET;
            end

            S_CHECK_SUBSET: begin
                if (is_subset) next_state = S_RESET_ADDED;
                else next_state = S_NEXT_MASK;
            end

            S_RESET_ADDED: begin
                next_state = S_LOOP_BITS;
            end

            S_LOOP_BITS: begin
                if (bit_index >= 4'd12) next_state = S_CHECK_VALID;
                else if (mask[bit_index]) next_state = S_ADD_EDGE;
                else next_state = S_NEXT_BIT;
            end

            S_ADD_EDGE: begin
                next_state = S_NEXT_BIT;
            end

            S_NEXT_BIT: begin
                next_state = S_LOOP_BITS;
            end

            S_CHECK_VALID: begin
                next_state = S_NEXT_MASK;
            end

            S_NEXT_MASK: begin
                next_state = S_LOOP_MASK;
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule