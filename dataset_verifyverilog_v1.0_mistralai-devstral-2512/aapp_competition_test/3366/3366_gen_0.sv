module SumIterations(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] L,
    input wire [7:0] R,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPUTING_F = 2'd1;
    localparam [1:0] ADDING    = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [7:0] current_X;
    reg [7:0] outer_counter;
    reg [31:0] current_sum;
    reg [31:0] iteration_count;
    reg [31:0] cycle_counter;
    localparam [31:0] MODULUS = 32'd1000000007;
    localparam [31:0] MAX_CYCLES = 32'd65536;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_X <= 8'd0;
            outer_counter <= 8'd0;
            current_sum <= 32'd0;
            iteration_count <= 32'd0;
            cycle_counter <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 32'd0;
                    if (start) begin
                        next_state <= COMPUTING_F;
                        current_X <= L;
                        outer_counter <= L;
                        current_sum <= 32'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTING_F: begin
                    cycle_counter <= cycle_counter + 32'd1;
                    
                    // Compute f(X) iterations
                    if (current_X == 8'd1) begin
                        // X=1: 0 iterations
                        iteration_count <= 32'd0;
                        next_state <= ADDING;
                    end else if (current_X[0] == 1'b0) begin
                        // X is even: X = X/2
                        current_X <= current_X >> 1;
                        iteration_count <= iteration_count + 32'd1;
                        next_state <= COMPUTING_F;
                    end else begin
                        // X is odd: X = X + 1
                        current_X <= current_X + 8'd1;
                        iteration_count <= iteration_count + 32'd1;
                        next_state <= COMPUTING_F;
                    end
                end

                ADDING: begin
                    // Add iteration_count to current_sum with modulo
                    current_sum <= (current_sum + iteration_count) % MODULUS;
                    iteration_count <= 32'd0;
                    
                    // Move to next X
                    if (outer_counter == R) begin
                        next_state <= DONE_STATE;
                        result <= current_sum;
                    end else begin
                        outer_counter <= outer_counter + 8'd1;
                        current_X <= outer_counter;
                        next_state <= COMPUTING_F;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule