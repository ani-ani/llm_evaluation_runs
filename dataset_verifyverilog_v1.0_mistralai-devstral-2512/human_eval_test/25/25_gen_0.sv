module prime_factorizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [7:0] factors [0:15],
    output reg [3:0] valid_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] current_n;
    reg [7:0] current_factor;
    reg [7:0] sqrt_n;
    reg [3:0] factor_count;
    reg [9:0] cycle_counter;
    localparam [9:0] MAX_CYCLES = 10'd512;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_n <= 8'd0;
            current_factor <= 8'd0;
            sqrt_n <= 8'd0;
            factor_count <= 4'd0;
            cycle_counter <= 10'd0;
            done <= 1'b0;
            valid_len <= 4'd0;
            
            // Initialize factors array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                factors[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_len <= 4'd0;
                    cycle_counter <= 10'd0;
                    
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize computation
                    current_n <= n;
                    current_factor <= 8'd2;
                    factor_count <= 4'd0;
                    
                    // Calculate sqrt(n) approximation
                    integer j;
                    sqrt_n <= 8'd0;
                    for (j = 0; j < 8; j = j + 1) begin
                        if ((j * j) <= n && ((j + 1) * (j + 1)) > n) begin
                            sqrt_n <= j;
                        end
                    end
                    
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_counter <= cycle_counter + 10'd1;
                    
                    // Check if we've exceeded max cycles
                    if (cycle_counter >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                    // Check if current_n is 1 (done)
                    else if (current_n == 8'd1) begin
                        next_state <= FINISH;
                    end
                    // Check if current_factor exceeds sqrt_n
                    else if (current_factor > sqrt_n) begin
                        // Add remaining current_n if > 1
                        if (current_n > 8'd1) begin
                            factors[factor_count] <= current_n;
                            factor_count <= factor_count + 4'd1;
                        end
                        next_state <= FINISH;
                    end
                    else begin
                        // Trial division
                        if (current_n % current_factor == 8'd0) begin
                            // Factor found
                            factors[factor_count] <= current_factor;
                            factor_count <= factor_count + 4'd1;
                            current_n <= current_n / current_factor;
                            sqrt_n <= current_n / current_factor; // Update sqrt
                        end else begin
                            // Move to next factor
                            current_factor <= current_factor + 8'd1;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    valid_len <= factor_count;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule