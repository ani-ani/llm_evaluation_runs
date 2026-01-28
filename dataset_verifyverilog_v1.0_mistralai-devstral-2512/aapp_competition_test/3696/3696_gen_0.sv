module PolynomialGenerator(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg result_valid,
    output reg [4:0] poly1_coeff_count,
    output reg [61:0] poly1_coeffs,
    output reg [4:0] poly2_coeff_count,
    output reg [61:0] poly2_coeffs
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] UPDATE  = 3'd3;
    localparam [2:0] OUTPUT  = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] iteration;
    reg [7:0] coeff_index;
    reg [1:0] temp_coeff;
    reg [61:0] new_A, new_B;
    reg [61:0] A, B;
    reg [4:0] A_count, B_count;
    reg [4:0] new_A_count, new_B_count;
    reg valid_flag;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd999;

    // Initialize polynomials
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iteration <= 8'd0;
            coeff_index <= 8'd0;
            A <= 62'd0;
            B <= 62'd0;
            A_count <= 5'd1;
            B_count <= 5'd1;
            A[1:0] <= 2'd1;  // A = [1]
            B[1:0] <= 2'd1;  // B = [1]
            new_A <= 62'd0;
            new_B <= 62'd0;
            new_A_count <= 5'd0;
            new_B_count <= 5'd0;
            valid_flag <= 1'b0;
            result_valid <= 1'b0;
            poly1_coeff_count <= 5'd0;
            poly1_coeffs <= 62'd0;
            poly2_coeff_count <= 5'd0;
            poly2_coeffs <= 62'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && n > 8'd0 && n <= 8'd150) begin
                        next_state <= COMPUTE;
                        iteration <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end else if (iteration == n - 8'd1) begin
                        next_state <= OUTPUT;
                    end else begin
                        // Compute new_A = [0] + A
                        new_A <= {2'd0, A[61:2]};
                        new_A_count <= A_count + 5'd1;
                        
                        // Compute new_B = A
                        new_B <= A;
                        new_B_count <= A_count;
                        
                        coeff_index <= 8'd0;
                        next_state <= CHECK;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end else if (coeff_index < B_count) begin
                        // Add B coefficient to new_A
                        temp_coeff <= new_A[(coeff_index * 2) + 1:coeff_index * 2] + B[(coeff_index * 2) + 1:coeff_index * 2];
                        
                        // Check if result is in {-1, 0, 1}
                        if (temp_coeff == 2'd0 || temp_coeff == 2'd1 || temp_coeff == 2'd3) begin
                            new_A[(coeff_index * 2) + 1:coeff_index * 2] <= temp_coeff;
                            coeff_index <= coeff_index + 8'd1;
                            next_state <= CHECK;
                        end else begin
                            // Try subtraction
                            temp_coeff <= new_A[(coeff_index * 2) + 1:coeff_index * 2] - B[(coeff_index * 2) + 1:coeff_index * 2];
                            if (temp_coeff == 2'd0 || temp_coeff == 2'd1 || temp_coeff == 2'd3) begin
                                new_A[(coeff_index * 2) + 1:coeff_index * 2] <= temp_coeff;
                                coeff_index <= coeff_index + 8'd1;
                                next_state <= CHECK;
                            end else begin
                                // Invalid, keep original
                                coeff_index <= coeff_index + 8'd1;
                                next_state <= CHECK;
                            end
                        end
                    end else begin
                        next_state <= UPDATE;
                    end
                end

                UPDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end else begin
                        // Update A and B
                        A <= new_A;
                        B <= new_B;
                        A_count <= new_A_count;
                        B_count <= new_B_count;
                        
                        iteration <= iteration + 8'd1;
                        next_state <= COMPUTE;
                    end
                end

                OUTPUT: begin
                    // Ensure leading coefficient is 1
                    if (A[61:60] == 2'd1) begin
                        poly1_coeff_count <= A_count;
                        poly1_coeffs <= A;
                        poly2_coeff_count <= B_count;
                        poly2_coeffs <= B;
                        result_valid <= 1'b1;
                    end else begin
                        // Shift to make leading coefficient 1
                        poly1_coeff_count <= A_count - 5'd1;
                        poly1_coeffs <= A[61:2];
                        poly2_coeff_count <= B_count - 5'd1;
                        poly2_coeffs <= B[61:2];
                        result_valid <= 1'b1;
                    end
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    result_valid <= 1'b0;
                end
            endcase
        end
    end

endmodule