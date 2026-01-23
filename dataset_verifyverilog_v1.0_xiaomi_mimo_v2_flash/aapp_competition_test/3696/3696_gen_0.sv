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
    localparam [1:0] DONE    = 2'd2;

    reg [1:0] state;
    reg [3:0] i;  // iteration counter (2 to n)
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal state arrays
    reg signed [2:0] poly_prev1 [0:MAX_COEFF-1];  // P_{i-1}
    reg signed [2:0] poly_prev2 [0:MAX_COEFF-1];  // P_{i-2}
    reg signed [2:0] new_poly [0:MAX_COEFF-1];    // x * poly_prev1
    reg signed [2:0] candidate1 [0:MAX_COEFF-1];
    reg signed [2:0] candidate2 [0:MAX_COEFF-1];
    reg valid1, valid2;

    integer j;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE:    state <= start ? COMPUTE : IDLE;
                COMPUTE: state <= (i == n) ? DONE : COMPUTE;
                DONE:    state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end

    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            i <= 4'd0;
            cycle_count <= 8'd0;
            
            // Initialize degrees
            out_degree1 <= 4'd0;
            out_degree2 <= 4'd0;
            
            // Initialize polynomials
            poly_prev2[0] <= 3'sd1;  // P0: [1]
            for (j = 0; j < MAX_COEFF; j = j + 1) begin
                if (j == 0) begin
                    poly_prev2[j] <= 3'sd1;
                    poly_prev1[j] <= 3'sd0;
                end else if (j == 1) begin
                    poly_prev1[j] <= 3'sd1;
                end else begin
                    poly_prev2[j] <= 3'sd0;
                    poly_prev1[j] <= 3'sd0;
                end
                new_poly[j] <= 3'sd0;
                candidate1[j] <= 3'sd0;
                candidate2[j] <= 3'sd0;
                out_coeffs1[j] <= 3'sd0;
                out_coeffs2[j] <= 3'sd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        if (n == 4'd1) begin
                            // Special case: n=1
                            out_degree1 <= 4'd1;
                            out_degree2 <= 4'd0;
                            out_coeffs1[0] <= 3'sd0;
                            out_coeffs1[1] <= 3'sd1;
                            out_coeffs2[0] <= 3'sd1;
                            for (j = 1; j < MAX_COEFF; j = j + 1) begin
                                out_coeffs2[j] <= 3'sd0;
                            end
                            done <= 1'b1;
                        end else begin
                            i <= 4'd2;
                            // Reset polynomials for n>=2
                            poly_prev2[0] <= 3'sd1;
                            poly_prev2[1] <= 3'sd0;
                            poly_prev1[0] <= 3'sd0;
                            poly_prev1[1] <= 3'sd1;
                            for (j = 2; j < MAX_COEFF; j = j + 1) begin
                                poly_prev1[j] <= 3'sd0;
                                poly_prev2[j] <= 3'sd0;
                            end
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute new_poly = x * poly_prev1
                    new_poly[0] <= 3'sd0;
                    for (j = 0; j < MAX_COEFF-1; j = j + 1) begin
                        if (j < i-1) begin
                            new_poly[j+1] <= poly_prev1[j];
                        end else if (j == MAX_COEFF-1) begin
                            new_poly[j] <= 3'sd0;
                        end else begin
                            new_poly[j+1] <= 3'sd0;
                        end
                    end
                    
                    // Compute candidates
                    valid1 <= 1'b1;
                    valid2 <= 1'b1;
                    
                    for (j = 0; j < MAX_COEFF; j = j + 1) begin
                        if (j < i-1) begin
                            // Candidates based on poly_prev2
                            candidate1[j] <= new_poly[j] + poly_prev2[j];
                            candidate2[j] <= new_poly[j] - poly_prev2[j];
                            
                            // Validity check
                            if (candidate1[j] != 3'sd0 && 
                                candidate1[j] != 3'sd1 && 
                                candidate1[j] != -3'sd1) begin
                                valid1 <= 1'b0;
                            end
                            if (candidate2[j] != 3'sd0 && 
                                candidate2[j] != 3'sd1 && 
                                candidate2[j] != -3'sd1) begin
                                valid2 <= 1'b0;
                            end
                        end else begin
                            // Last coefficients match new_poly
                            candidate1[j] <= new_poly[j];
                            candidate2[j] <= new_poly[j];
                        end
                    end
                    
                    // Choose valid candidate for next polynomial
                    if (valid1) begin
                        for (j = 0; j < MAX_COEFF; j = j + 1) begin
                            if (j < i) begin
                                poly_prev1[j] <= candidate1[j];
                            end
                        end
                    end else if (valid2) begin
                        for (j = 0; j < MAX_COEFF; j = j + 1) begin
                            if (j < i) begin
                                poly_prev1[j] <= candidate2[j];
                            end
                        end
                    end
                    
                    // Shift history
                    for (j = 0; j < MAX_COEFF; j = j + 1) begin
                        poly_prev2[j] <= poly_prev1[j];
                    end
                    
                    // Check completion
                    if (i == n) begin
                        // Prepare output
                        out_degree1 <= n;
                        out_degree2 <= n - 4'd1;
                        for (j = 0; j < MAX_COEFF; j = j + 1) begin
                            if (j < n + 1) begin
                                out_coeffs1[j] <= poly_prev1[j];
                            end else begin
                                out_coeffs1[j] <= 3'sd0;
                            end
                            if (j < n) begin
                                out_coeffs2[j] <= poly_prev2[j];
                            end else begin
                                out_coeffs2[j] <= 3'sd0;
                            end
                        end
                        done <= 1'b1;
                    end else begin
                        i <= i + 4'd1;
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule