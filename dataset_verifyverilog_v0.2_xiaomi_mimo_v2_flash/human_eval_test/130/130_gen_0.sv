module tribonacci (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [31:0] result,
    output reg valid,
    output reg busy
);

    // State encoding
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        COMPUTE = 2'b01,
        DONE = 2'b10
    } state_t;

    state_t current_state, next_state;

    // Internal registers and wires
    reg [7:0] current_n;
    reg [7:0] next_n;
    reg [31:0] tri_n_minus_1; // Stores tri(n-1)
    reg [31:0] tri_n_minus_2; // Stores tri(n-2)
    reg [31:0] next_result;
    reg [31:0] calc_val;
    
    // Q16.16 constants
    wire [31:0] one_fp = 32'h0001_0000;
    wire [31:0] two_fp = 32'h0002_0000;

    // State transition and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_n <= 8'h0;
            result <= 32'h0;
            valid <= 1'b0;
            busy <= 1'b0;
            tri_n_minus_1 <= 32'h0;
            tri_n_minus_2 <= 32'h0;
        end else begin
            // Default assignments
            valid <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        current_state <= COMPUTE;
                        busy <= 1'b1;
                        current_n <= n;
                        
                        // Initialize base cases based on input n
                        // We need to handle transitions carefully
                        if (n == 0) begin
                            // tri(0) = 1
                            result <= one_fp;
                            current_state <= DONE;
                            busy <= 1'b0;
                            valid <= 1'b1;
                        end else if (n == 1) begin
                            // tri(1) = 3
                            result <= 32'h0003_0000;
                            current_state <= DONE;
                            busy <= 1'b0;
                            valid <= 1'b1;
                        end else if (n == 2) begin
                            // tri(2) = 2
                            result <= two_fp;
                            current_state <= DONE;
                            busy <= 1'b0;
                            valid <= 1'b1;
                        end else begin
                            // For n > 2, start iterative calculation
                            // Initialize for n=3 (the first n > 2 we might compute)
                            // We will work backwards or forwards? 
                            // Recurrence implies: 
                            // Even: 1 + n/2
                            // Odd: tri(n-1) + tri(n-2) + tri(n+1)
                            // Note: The spec says "compute from base cases up to n"
                            // So we iterate from 0 to n.
                            // We need to store tri(i-1) and tri(i-2)
                            
                            // For the first step of the loop (i=3):
                            // i is odd. tri(3) = tri(2) + tri(1) + tri(4)
                            // Wait, tri(4) is future. The spec says "effective computation" 
                            // tri(n) = (1 + (n+1)/2) + tri(n-1) + tri(n-2)
                            // This allows iterative computation.
                            
                            // Let's pre-fill base cases for iteration
                            // We need to iterate from 3 up to n.
                            // So at state transition to COMPUTE:
                            // i = 3
                            // tri_n_minus_2 = tri(1) = 3
                            // tri_n_minus_1 = tri(2) = 2
                            // current_n holds the target n.
                            
                            // Logic to set initial iter values:
                            tri_n_minus_2 <= 32'h0003_0000; // tri(1)
                            tri_n_minus_1 <= two_fp;        // tri(2)
                            current_n <= 32'd3;             // Start calculation at n=3
                        end
                    end
                end

                COMPUTE: begin
                    // Check if we reached target n
                    if (current_n > n) begin
                        // We overshoot by 1 because we update at end of cycle.
                        // The result is in tri_n_minus_1 (which holds tri(current_n-1))
                        // Wait, let's trace:
                        // If n=3. Target=3.
                        // State transition: curr_n=3.
                        // Calc: calc_val = tri(3).
                        // Update: tri_n_minus_2 <= tri_n_minus_1 (tri(2))
                        //         tri_n_minus_1 <= calc_val (tri(3))
                        //         current_n <= 4.
                        // Next cycle: current_n=4. Check condition (4 > 3) -> True.
                        // So result should be in tri_n_minus_1.
                        result <= tri_n_minus_1;
                        current_state <= DONE;
                        busy <= 1'b0;
                        valid <= 1'b1;
                    end else begin
                        // Calculate tri(current_n)
                        if (current_n[0] == 1'b0) begin
                            // Even: 1 + n/2
                            // Q16.16: value = 1.0 + (n >> 1)
                            calc_val <= one_fp + {16'b0, current_n[7:1], 16'b0};
                        end else begin
                            // Odd: tri(n-1) + tri(n-2) + (1 + (n+1)/2)
                            // term3 = 1 + (n+1)/2 = 1 + (current_n >> 1) + 1 (if we consider integer division truncation)
                            // Actually, (n+1)/2 for integer n (odd) is (n+1) >> 1.
                            // e.g. n=3 -> (3+1)/2 = 2. n=5 -> 3.
                            // Q16.16: term3 = 1.0 + ((current_n + 1) >> 1)
                            
                            calc_val <= tri_n_minus_1 + tri_n_minus_2 + one_fp + {16'b0, (current_n + 1) >> 1, 16'b0};
                        end
                        
                        // Update registers for next iteration
                        tri_n_minus_2 <= tri_n_minus_1;
                        tri_n_minus_1 <= calc_val; // Note: This causes a 1 cycle delay. Is that okay?
                        // If we use calc_val immediately for the next cycle's dependency, we need to be careful.
                        // But tri(n) depends on tri(n-1) and tri(n-2). 
                        // If we are calculating n=4 (even), we need tri(3) and tri(2).
                        // tri(3) was just calculated in prev cycle.
                        // So tri_n_minus_1 should hold tri(3) when calculating tri(4).
                        // This implies we update tri_n_minus_1 with the PREVIOUS calc_val.
                        // Wait, in the first cycle of compute (curr_n=3), we calculate tri(3).
                        // Then we update regs: tri_n_minus_1 becomes tri(3), tri_n_minus_2 becomes tri(2).
                        // Next cycle (curr_n=4), we calculate tri(4). We use tri(3) and tri(2).
                        // Correct.
                        
                        current_n <= current_n + 1;
                    end
                end

                DONE: begin
                    // Wait for reset or new start (implicitly handled by IDLE transition logic usually, 
                    // but here we need to return to IDLE).
                    // The requirement says "Return to IDLE when ready for next computation".
                    // Usually, we go DONE -> IDLE on the next cycle or when start is low.
                    // Let's go IDLE immediately to be ready for next start.
                    current_state <= IDLE;
                    valid <= 1'b0; // Pulse valid in DONE, clear here
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule