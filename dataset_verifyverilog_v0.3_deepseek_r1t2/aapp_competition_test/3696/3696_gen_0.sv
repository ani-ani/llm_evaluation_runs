module polynomial_generator #(
    parameter MAX_N = 8,
    parameter MAX_COEFF = MAX_N + 1
) (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg done,
    output reg [3:0] out_degree1,
    output reg [3:0] out_degree2,
    output reg [2:0] out_coeffs1 [0:MAX_COEFF-1],
    output reg [2:0] out_coeffs2 [0:MAX_COEFF-1]
);

    // State encoding
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_ST = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] i; // Iteration counter (2 to n)
    reg signed [2:0] poly_prev1 [0:MAX_COEFF-1]; // P_{i-1}
    reg signed [2:0] poly_prev2 [0:MAX_COEFF-1]; // P_{i-2}
    reg signed [2:0] new_poly [0:MAX_COEFF-1];   // x * poly_prev1
    reg signed [2:0] candidate1 [0:MAX_COEFF-1];
    reg signed [2:0] candidate2 [0:MAX_COEFF-1];
    reg valid1, valid2;
    reg [7:0] cycle_counter;
    
    integer j;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            i <= 4'd2;
            out_degree1 <= 4'd0;
            out_degree2 <= 4'd0;
            cycle_counter <= 8'd0;
            
            // Initialize polynomial arrays
            for (j=0; j<MAX_COEFF; j=j+1) begin
                poly_prev1[j] <= 3'sd0;
                poly_prev2[j] <= 3'sd0;
                new_poly[j] <= 3'sd0;
                candidate1[j] <= 3'sd0;
                candidate2[j] <= 3'sd0;
                out_coeffs1[j] <= 3'sd0;
                out_coeffs2[j] <= 3'sd0;
            end
            
            // Initial polynomials P_0 and P_1
            poly_prev2[0] <= 3'sd1; // P0 = [1]
            poly_prev1[0] <= 3'sd0; // P1 = [0,1]
            poly_prev1[1] <= 3'sd1;
        end else begin
            cycle_counter <= cycle_counter + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid1 <= 1'b0;
                    valid2 <= 1'b0;
                    cycle_counter <= 8'd0;
                    
                    if (start) begin
                        if (n == 4'd1) begin
                            // Handle n=1 case immediately
                            out_degree1 <= 4'd1;
                            out_degree2 <= 4'd0;
                            out_coeffs1[0] <= 3'sd0;
                            out_coeffs1[1] <= 3'sd1;
                            out_coeffs2[0] <= 3'sd1;
                            done <= 1'b1;
                            next_state <= DONE_ST;
                        end else begin
                            i <= 4'd2;
                            next_state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Compute new_poly = x * poly_prev1 (shift left)
                    new_poly[0] <= 3'sd0;
                    for (j=0; j<MAX_COEFF-1; j=j+1) begin
                        new_poly[j+1] <= poly_prev1[j];
                    end
                    new_poly[MAX_COEFF] <= 3'sd0;
                    
                    // Compute candidates
                    valid1 <= 1'b1;
                    valid2 <= 1'b1;
                    for (j=0; j<MAX_COEFF; j=j+1) begin
                        candidate1[j] <= new_poly[j] + poly_prev2[j];
                        candidate2[j] <= new_poly[j] - poly_prev2[j];
                        
                        // Validate coefficients
                        if (candidate1[j] != 3'sd1 && candidate1[j] != 3'sd0 && candidate1[j] != -3'sd1)
                            valid1 <= 1'b0;
                        if (candidate2[j] != 3'sd1 && candidate2[j] != 3'sd0 && candidate2[j] != -3'sd1)
                            valid2 <= 1'b0;
                    end
                    
                    // Update polynomials if valid
                    if (valid1) begin
                        for (j=0; j<MAX_COEFF; j=j+1) begin
                            poly_prev2[j] <= poly_prev1[j];
                            poly_prev1[j] <= candidate1[j];
                        end
                    end else if (valid2) begin
                        for (j=0; j<MAX_COEFF; j=j+1) begin
                            poly_prev2[j] <= poly_prev1[j];
                            poly_prev1[j] <= candidate2[j];
                        end
                    end
                    
                    // Check completion
                    if (i == n) begin
                        next_state <= DONE_ST;
                    end else begin
                        i <= i + 4'd1;
                        if (cycle_counter > 8'd100) next_state <= IDLE; // Timeout
                    end
                end
                
                DONE_ST: begin
                    // Output results
                    out_degree1 <= n;
                    out_degree2 <= n - 4'd1;
                    for (j=0; j<MAX_COEFF; j=j+1) begin
                        out_coeffs1[j] <= poly_prev1[j];
                        out_coeffs2[j] <= poly_prev2[j];
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE:    next_state = start ? (n == 4'd1 ? DONE_ST : COMPUTE) : IDLE;
            COMPUTE: next_state = (i == n) ? DONE_ST : COMPUTE;
            DONE_ST: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule