module slon_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [19:0] a,
    input wire [19:0] b,
    input wire [19:0] P,
    input wire [19:0] M,
    output reg [19:0] x_out,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE_T = 3'd1;
    localparam [2:0] EUCLID    = 3'd2;
    localparam [2:0] SOLVE     = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    
    reg [2:0] state;
    reg [19:0] target;
    reg [19:0] r0, r1, r2;
    reg [19:0] s0, s1, s2;
    reg [19:0] t0, t1, t2;
    reg [19:0] q;
    reg [19:0] inv_a;
    reg [19:0] x_temp;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            target <= 20'd0;
            r0 <= 20'd0; r1 <= 20'd0; r2 <= 20'd0;
            s0 <= 20'd0; s1 <= 20'd0; s2 <= 20'd0;
            t0 <= 20'd0; t1 <= 20'd0; t2 <= 20'd0;
            q <= 20'd0;
            inv_a <= 20'd0;
            x_temp <= 20'd0;
            x_out <= 20'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_T;
                    end
                end
                
                COMPUTE_T: begin
                    // Compute target = (P - b) % M
                    if (P >= b) begin
                        target <= P - b;
                    end else begin
                        target <= P - b + M;
                    end
                    
                    // Initialize Extended Euclidean Algorithm
                    r0 <= M;
                    r1 <= a;
                    s0 <= 20'd1;
                    s1 <= 20'd0;
                    t0 <= 20'd0;
                    t1 <= 20'd1;
                    
                    state <= EUCLID;
                end
                
                EUCLID: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute quotient
                    if (r1 != 20'd0) begin
                        q <= r0 / r1;
                        
                        // Update remainders
                        r2 <= r0 - q * r1;
                        
                        // Update coefficients
                        s2 <= s0 - q * s1;
                        t2 <= t0 - q * t1;
                        
                        // Shift registers
                        r0 <= r1;
                        r1 <= r2;
                        s0 <= s1;
                        s1 <= s2;
                        t0 <= t1;
                        t1 <= t2;
                        
                        // Continue if r1 != 0
                        if (r1 == 20'd0) begin
                            // Check if solution exists
                            if (r0 == 20'd1) begin
                                inv_a <= t0;
                                state <= SOLVE;
                            end else begin
                                // No solution (but problem guarantees solution)
                                state <= IDLE;
                            end
                        end
                    end else begin
                        // No solution (but problem guarantees solution)
                        state <= IDLE;
                    end
                    
                    // Prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end
                
                SOLVE: begin
                    // Compute x = (target * inv_a) % M
                    x_temp <= target * inv_a;
                    
                    // Ensure non-negative
                    if (x_temp < 20'd0) begin
                        x_out <= x_temp + M;
                    end else begin
                        x_out <= x_temp % M;
                    end
                    
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule