module binary_sequence_counter(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;
    
    // Internal registers for computation
    reg [7:0] r;
    reg [15:0] c_nr;
    reg [15:0] c_nr_prev;
    reg [31:0] sum_squares;
    reg [31:0] temp_product;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            r <= 8'd0;
            c_nr <= 16'd0;
            c_nr_prev <= 16'd0;
            sum_squares <= 32'd0;
            temp_product <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        r <= 8'd0;
                        c_nr <= 16'd1;  // C(n,0) = 1
                        c_nr_prev <= 16'd1;
                        sum_squares <= 32'd1;  // Start with 1 (for r=0)
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute C(n,r) = C(n,r-1) * (n - r + 1) / r
                    if (r < n) begin
                        temp_product <= c_nr_prev * (n - r + 1);
                        c_nr <= temp_product / (r + 1);
                        
                        // Accumulate sum of squares
                        temp_product <= c_nr * c_nr;
                        sum_squares <= sum_squares + temp_product;
                        
                        // Update for next iteration
                        c_nr_prev <= c_nr;
                        r <= r + 8'd1;
                    end else begin
                        // Final result: 1 + sum(C(n,r)^2 for r=1 to n)
                        // Convert to Q8.8 by multiplying by 256
                        result <= (sum_squares << 8);
                        state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
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