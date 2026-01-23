module perfect_square_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] DONE  = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] i;           // Counter for divisor search
    reg [7:0] i_squared;  // i*i result
    reg [7:0] n_div_i;    // n/i result
    reg [7:0] n_mod_i;    // n%i result
    reg [3:0] cycle_count; // Prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd16;
    
    // Combinational logic for arithmetic operations
    wire [15:0] i_squared_temp = $signed(i) * $signed(i);
    wire [15:0] n_div_i_temp = $signed(n) / $signed(i);
    wire [15:0] n_mod_i_temp = $signed(n) % $signed(i);
    
    always @(*) begin
        i_squared = i_squared_temp[7:0];
        n_div_i = n_div_i_temp[7:0];
        n_mod_i = n_mod_i_temp[7:0];
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 8'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= CHECK;
                        i <= 8'd1;  // Start checking from i=1
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if i*i <= n
                    if (i_squared <= n) begin
                        // Check if n is divisible by i and n/i equals i
                        if ((n_mod_i == 8'd0) && (n_div_i == i)) begin
                            result <= 1'b1;
                            state <= DONE;
                        end else begin
                            // Increment i for next iteration
                            i <= i + 8'd1;
                            
                            // Continue checking if we haven't exceeded max cycles
                            if (cycle_count >= MAX_CYCLES) begin
                                result <= 1'b0;
                                state <= DONE;
                            end
                        end
                    end else begin
                        // i*i > n, no perfect square found
                        result <= 1'b0;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Special case for n=0 (0 is a perfect square)
    always @(*) begin
        if (n == 8'd0) begin
            result = 1'b1;
        end
    end
endmodule