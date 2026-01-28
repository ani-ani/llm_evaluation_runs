module SumOfFourthPowers (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [19:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] ACCUMULATE = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] i;              // Counter: 1 to n
    reg [3:0] n_reg;          // Registered n value
    reg [31:0] accumulator;   // 32-bit accumulator for sum
    reg [15:0] odd;           // Odd number (2*i - 1)
    reg [15:0] temp1;         // First multiplication result
    reg [31:0] temp2;         // Second multiplication result (max: 15^4 = 50625)
    reg [7:0] cycle_count;    // Safety counter
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 20'd0;
            done <= 1'b0;
            i <= 4'd0;
            n_reg <= 4'd0;
            accumulator <= 32'd0;
            odd <= 16'd0;
            temp1 <= 16'd0;
            temp2 <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load n and initialize
                        n_reg <= n;
                        accumulator <= 32'd0;
                        i <= 4'd1;  // Start from i=1
                    end
                end
                
                LOAD: begin
                    // Calculate odd number: 2*i - 1
                    odd <= (i << 1) - 16'd1;
                end
                
                COMPUTE: begin
                    // First multiplication: odd * odd
                    temp1 <= odd * odd;
                end
                
                ACCUMULATE: begin
                    // Second multiplication: temp1 * odd * odd
                    // Accumulate into result
                    temp2 <= temp1 * temp1;  // (odd^2)^2 = odd^4
                    
                    // Add to accumulator (accumulator <= accumulator + temp2)
                    accumulator <= accumulator + (temp1 * temp1);
                    
                    // Increment i
                    i <= i + 4'd1;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= accumulator[19:0];  // Truncate to 20 bits
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                next_state = ACCUMULATE;
            end
            
            ACCUMULATE: begin
                // Check if computation is complete
                if (i > n_reg || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = LOAD;
                end
            end
            
            FINISH: begin
                // Return to IDLE after one cycle
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule