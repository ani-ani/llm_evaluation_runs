module ProblemModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [12:0] P_scaled,
    output reg [7:0] a1,
    output reg [7:0] a2,
    output reg [7:0] a3,
    output reg [7:0] a4,
    output reg [7:0] a5,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] CHECK_N    = 4'd1;
    localparam [3:0] MULT_WAIT  = 4'd2;
    localparam [3:0] CHECK_DIV  = 4'd3;
    localparam [3:0] FIND_SOLUTION = 4'd4;
    localparam [3:0] ASSIGN_OUTPUTS = 4'd5;
    localparam [3:0] FINISH     = 4'd6;
    localparam [3:0] NO_SOLUTION = 4'd7;

    reg [3:0] state;
    reg [7:0] n;
    reg [23:0] prod_result;
    reg [23:0] prod_temp;
    reg [7:0] prod_counter;
    reg [7:0] S;
    
    // Variables for nested loops
    reg [7:0] a5_loop;
    reg [7:0] a4_loop;
    reg [7:0] a3_loop;
    reg [7:0] a2_loop;
    reg [7:0] a1_temp;
    reg found_solution;
    
    // Output registers (declared as reg already)
    reg [7:0] out_a1, out_a2, out_a3, out_a4, out_a5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n <= 8'd0;
            prod_result <= 24'd0;
            prod_temp <= 24'd0;
            prod_counter <= 8'd0;
            S <= 8'd0;
            a5_loop <= 8'd0;
            a4_loop <= 8'd0;
            a3_loop <= 8'd0;
            a2_loop <= 8'd0;
            a1_temp <= 8'd0;
            found_solution <= 1'b0;
            out_a1 <= 8'd0;
            out_a2 <= 8'd0;
            out_a3 <= 8'd0;
            out_a4 <= 8'd0;
            out_a5 <= 8'd0;
            a1 <= 8'd0;
            a2 <= 8'd0;
            a3 <= 8'd0;
            a4 <= 8'd0;
            a5 <= 8'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0; // Default, clear done unless specified
            
            case (state)
                IDLE: begin
                    if (start) begin
                        n <= 8'd1;
                        found_solution <= 1'b0;
                        state <= CHECK_N;
                    end
                end

                CHECK_N: begin
                    if (n > 8'd256) begin
                        state <= NO_SOLUTION;
                    end else begin
                        // Start multiplication P_scaled * n
                        prod_result <= 24'd0;
                        prod_temp <= {11'd0, P_scaled}; // Zero extend to 24 bits
                        prod_counter <= 8'd0;
                        state <= MULT_WAIT;
                    end
                end

                MULT_WAIT: begin
                    // Multiply P_scaled * n by repeated addition (n times)
                    if (prod_counter < n) begin
                        prod_result <= prod_result + prod_temp;
                        prod_counter <= prod_counter + 8'd1;
                    end else begin
                        state <= CHECK_DIV;
                    end
                end

                CHECK_DIV: begin
                    // Check if prod_result is divisible by 1000
                    // prod_result is 24-bit, max value for P=5.0, n=256 is 5000*256 = 1,280,000 (fits in 24 bits)
                    // Using modulo operation directly
                    if (prod_result % 1000 == 24'd0) begin
                        S <= prod_result / 1000; // This is integer division, clean because divisible
                        // Initialize nested loops
                        a5_loop <= 8'd0;
                        a4_loop <= 8'd0;
                        a3_loop <= 8'd0;
                        a2_loop <= 8'd0;
                        found_solution <= 1'b0;
                        state <= FIND_SOLUTION;
                    end else begin
                        n <= n + 8'd1;
                        state <= CHECK_N;
                    end
                end

                FIND_SOLUTION: begin
                    // Nested loops to find a1, a2, a3, a4, a5
                    if (!found_solution) begin
                        // Loop logic
                        if (a5_loop <= n) begin
                            if (a4_loop <= (n - a5_loop)) begin
                                if (a3_loop <= (n - a5_loop - a4_loop)) begin
                                    if (a2_loop <= (n - a5_loop - a4_loop - a3_loop)) begin
                                        // Calculate a1
                                        a1_temp <= n - a5_loop - a4_loop - a3_loop - a2_loop;
                                        
                                        // Check sum equation: a1 + 2*a2 + 3*a3 + 4*a4 + 5*a5 == S
                                        // a1 is already computed as n - (a5+a4+a3+a2)
                                        if ((a1_temp + 
                                             (a2_loop << 1) + 
                                             (a3_loop + a3_loop + a3_loop) + 
                                             (a4_loop << 2) + 
                                             (a5_loop + a5_loop + a5_loop + a5_loop + a5_loop)) == S) begin
                                            found_solution <= 1'b1;
                                            out_a1 <= a1_temp;
                                            out_a2 <= a2_loop;
                                            out_a3 <= a3_loop;
                                            out_a4 <= a4_loop;
                                            out_a5 <= a5_loop;
                                            state <= ASSIGN_OUTPUTS;
                                        end else begin
                                            a2_loop <= a2_loop + 8'd1;
                                        end
                                    end else begin
                                        a2_loop <= 8'd0;
                                        a3_loop <= a3_loop + 8'd1;
                                    end
                                end else begin
                                    a3_loop <= 8'd0;
                                    a4_loop <= a4_loop + 8'd1;
                                end
                            end else begin
                                a4_loop <= 8'd0;
                                a5_loop <= a5_loop + 8'd1;
                            end
                        end else begin
                            // Tried all combos for this n, no solution found (should not happen for valid P)
                            n <= n + 8'd1;
                            state <= CHECK_N;
                        end
                    end else begin
                        state <= ASSIGN_OUTPUTS;
                    end
                end

                ASSIGN_OUTPUTS: begin
                    a1 <= out_a1;
                    a2 <= out_a2;
                    a3 <= out_a3;
                    a4 <= out_a4;
                    a5 <= out_a5;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                NO_SOLUTION: begin
                    // Set all outputs to 0
                    a1 <= 8'd0;
                    a2 <= 8'd0;
                    a3 <= 8'd0;
                    a4 <= 8'd0;
                    a5 <= 8'd0;
                    state <= FINISH;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule