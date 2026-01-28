module MemoryGameSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Internal registers for computation
    reg [3:0] current_n;
    reg [31:0] e_prev2;  // E(N-2) in Q16.16
    reg [31:0] e_prev1;  // E(N-1) in Q16.16
    reg [31:0] e_current; // E(N) in Q16.16
    reg [3:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_n <= 4'd0;
            e_prev2 <= 32'd0;
            e_prev1 <= 32'd0;
            e_current <= 32'd0;
            i <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        current_n <= n;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Initialize base cases
                    if (i == 4'd0) begin
                        e_prev2 <= 32'd0;  // E(0) = 0.0 in Q16.16
                        e_prev1 <= 32'd65536;  // E(1) = 1.0 in Q16.16
                        i <= i + 4'd1;
                    end else if (i == 4'd1) begin
                        // E(2) = 1.0 + (E(1) + 2.0 * E(0)) / 3.0
                        // = 1.0 + (1.0 + 0.0) / 3.0 = 1.0 + 0.333... = 1.333...
                        e_current <= 32'd65536 + ((e_prev1 + (e_prev2 << 1'b1)) / 3'd3);
                        e_prev2 <= e_prev1;
                        e_prev1 <= e_current;
                        i <= i + 4'd1;
                    end else if (i < current_n) begin
                        // E(N) = 1.0 + (E(N-1) + 2.0 * E(N-2)) / 3.0
                        e_current <= 32'd65536 + ((e_prev1 + (e_prev2 << 1'b1)) / 3'd3);
                        e_prev2 <= e_prev1;
                        e_prev1 <= e_current;
                        i <= i + 4'd1;
                    end else begin
                        // Calculation complete
                        result <= e_current;
                        state <= FINISH;
                    end
                    
                    // Exit condition to prevent infinite loops
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