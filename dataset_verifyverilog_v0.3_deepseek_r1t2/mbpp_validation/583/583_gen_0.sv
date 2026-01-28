module catalan_number (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // DP array and counters
    reg [3:0] current_n;
    reg [3:0] j;
    reg [15:0] catalan [0:8];
    
    // Initialize array in reset
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize catalan[0]-[8]
            for (k = 0; k <= 8; k = k + 1) begin
                if (k <= 1) catalan[k] <= 16'd1;
                else catalan[k] <= 16'd0;
            end
            
            state <= IDLE;
            cycle_count <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            current_n <= 4'd0;
            j <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        cycle_count <= 8'd0;
                        // Handle edge cases
                        if (n <= 4'd1) begin
                            result <= 16'd1;
                            state <= FINISH;
                        end else if (n > 4'd8) begin
                            result <= catalan[8];  // C8=1430
                            state <= FINISH;
                        end else begin
                            current_n <= 4'd2;
                            j <= 4'd0;
                            catalan[current_n] <= 16'd0;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute: catalan[n] += catalan[j] * catalan[current_n-1-j]
                    catalan[current_n] <= catalan[current_n] + (catalan[j] * catalan[current_n - 4'd1 - j]);
                    j <= j + 4'd1;
                    
                    // Check completion condition
                    if (j == current_n - 4'd1) begin
                        if (current_n == n) begin
                            result <= catalan[current_n];
                            state <= FINISH;
                        end else begin
                            current_n <= current_n + 4'd1;
                            j <= 4'd0;
                            catalan[current_n + 4'd1] <= 16'd0;  // Prep for next n
                        end
                    end
                    
                    // Timeout safeguard
                    if (cycle_count >= MAX_CYCLES) state <= FINISH;
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