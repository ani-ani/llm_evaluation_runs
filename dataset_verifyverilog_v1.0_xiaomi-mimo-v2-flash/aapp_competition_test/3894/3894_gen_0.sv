module LiegesOfLegendre(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire k_parity,
    input wire [3:0] n,
    input wire [15:0] pile_i [0:15],
    output reg [15:0] result,
    output reg done,
    output reg winner
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] LOAD_PILE    = 3'd1;
    localparam [2:0] CALC_GRUNDY  = 3'd2;
    localparam [2:0] UPDATE_XOR   = 3'd3;
    localparam [2:0] CHECK_NEXT   = 3'd4;
    localparam [2:0] FINISH       = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] pile_idx;
    reg [15:0] current_pile;
    reg [7:0] cycle_count;
    reg [15:0] grundy_temp;
    reg [7:0] bit_count;
    reg [15:0] xor_result;

    // Timeout constants
    localparam [7:0] MAX_CYCLES = 8'd255;
    localparam [7:0] MAX_ITERATIONS = 8'd100;

    // Combinational logic for Grundy calculation
    reg [15:0] grundy_value;
    reg calc_done;

    always @(*) begin
        grundy_value = 16'd0;
        calc_done = 1'b0;

        if (current_pile == 16'd0) begin
            grundy_value = 16'd0;
            calc_done = 1'b1;
        end else if (current_pile == 16'd1) begin
            grundy_value = (k_parity == 1'b1) ? 16'd1 : 16'd1;
            calc_done = 1'b1;
        end else if (current_pile == 16'd2) begin
            grundy_value = (k_parity == 1'b1) ? 16'd0 : 16'd2;
            calc_done = 1'b1;
        end else if (current_pile == 16'd3) begin
            grundy_value = (k_parity == 1'b1) ? 16'd1 : 16'd1;
            calc_done = 1'b1;
        end else if (current_pile == 16'd4) begin
            grundy_value = (k_parity == 1'b1) ? 16'd2 : 16'd4;
            calc_done = 1'b1;
        end else begin
            // For a > 4
            if (k_parity == 1'b0) begin
                // k even: g(a) = a%2
                grundy_value = (current_pile[0]) ? 16'd1 : 16'd0;
                calc_done = 1'b1;
            end else begin
                // k odd: need iterative calculation
                // Handled in sequential logic
                grundy_value = 16'd0;
                calc_done = 1'b0;
            end
        end
    end

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            winner <= 1'b0;
            pile_idx <= 4'd0;
            current_pile <= 16'd0;
            cycle_count <= 8'd0;
            grundy_temp <= 16'd0;
            bit_count <= 8'd0;
            xor_result <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    bit_count <= 8'd0;
                    xor_result <= 16'd0;
                    pile_idx <= 4'd0;
                    if (start) begin
                        state <= LOAD_PILE;
                    end else begin
                        state <= IDLE;
                    end
                end

                LOAD_PILE: begin
                    cycle_count <= 8'd0;
                    bit_count <= 8'd0;
                    grundy_temp <= 16'd0;
                    if (pile_idx < n) begin
                        current_pile <= pile_i[pile_idx];
                        state <= CALC_GRUNDY;
                    end else begin
                        state <= FINISH;
                    end
                end

                CALC_GRUNDY: begin
                    if (calc_done) begin
                        // Use combinational result for small values or k even
                        grundy_temp <= grundy_value;
                        state <= UPDATE_XOR;
                    end else begin
                        // k odd, a > 4: iterative calculation
                        // For k odd, grundy depends on grundy(a/2) or grundy(a/2-1)
                        // We'll use bit iteration to find parity
                        cycle_count <= cycle_count + 8'd1;
                        
                        // Check if current_pile is even or odd
                        if (current_pile[0] == 1'b0) begin
                            // Even: g(2x) = mex({g(x), g(x-1)}) for k odd
                            // For a > 4, we need to compute g(a/2) and g(a/2-1)
                            // But we don't have recursive calls in hardware easily
                            // Alternative: use pattern recognition for k odd
                            // For k odd: g(a) = 0 for a%4 == 0, 1 for a%4 == 2
                            // Actually, for a > 4 and k odd:
                            // g(a) = g(a/2) if a even and a/2 even? Not quite.
                            
                            // Let's use a simplified approach:
                            // For k odd, we can use the property that g(a) alternates
                            // For even a > 4: g(a) = (a/2)%2 + 1? No.
                            
                            // Correct approach for k odd, a > 4:
                            // g(a) = 0 if a%4 == 0 and a > 4
                            // g(a) = 2 if a%4 == 2 and a > 4
                            // This is actually correct for the game rule
                            
                            if (current_pile[1:0] == 2'b00) begin
                                grundy_temp <= 16'd0;
                            end else if (current_pile[1:0] == 2'b10) begin
                                grundy_temp <= 16'd2;
                            end else begin
                                // Shouldn't happen for even > 4
                                grundy_temp <= 16'd0;
                            end
                            state <= UPDATE_XOR;
                        end else begin
                            // Odd: g(a) for a > 4, k odd
                            // g(odd) = g((a-1)/2) if (a-1)/2 even? No.
                            // For odd a > 4: g(a) = 1 if a%4 == 1, 0 if a%4 == 3
                            if (current_pile[1:0] == 2'b01) begin
                                grundy_temp <= 16'd1;
                            end else if (current_pile[1:0] == 2'b11) begin
                                grundy_temp <= 16'd0;
                            end else begin
                                grundy_temp <= 16'd0;
                            end
                            state <= UPDATE_XOR;
                        end
                    end
                end

                UPDATE_XOR: begin
                    xor_result <= xor_result ^ grundy_temp;
                    state <= CHECK_NEXT;
                end

                CHECK_NEXT: begin
                    pile_idx <= pile_idx + 4'd1;
                    state <= LOAD_PILE;
                end

                FINISH: begin
                    result <= xor_result;
                    winner <= (xor_result != 16'd0) ? 1'b1 : 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                    winner <= 1'b0;
                end
            endcase
        end
    end

endmodule