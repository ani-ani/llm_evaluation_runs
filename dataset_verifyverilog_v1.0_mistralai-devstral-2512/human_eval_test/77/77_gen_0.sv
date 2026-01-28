module perfect_cube_detector(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] a,
    output reg is_cube,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    // Candidate cube roots (n from -5 to 5)
    localparam signed [3:0] MIN_N = 4'sd(-5);
    localparam signed [3:0] MAX_N = 4'sd(5);

    // Registers
    reg [2:0] state, next_state;
    reg signed [3:0] n;
    reg signed [15:0] n_squared;
    reg signed [15:0] n_cubed;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_cube <= 1'b0;
            done <= 1'b0;
            n <= 4'sd(0);
            n_squared <= 16'sd(0);
            n_cubed <= 16'sd(0);
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    is_cube <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        n <= MIN_N;
                        next_state <= CHECK;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Compute n^2
                    n_squared <= $signed(n) * $signed(n);
                    
                    // Compute n^3
                    n_cubed <= n_squared * $signed(n);
                    
                    // Check if n^3 matches input a
                    if (n_cubed[7:0] == a) begin
                        is_cube <= 1'b1;
                        next_state <= FINISH;
                    end else if (n == MAX_N || cycle_count >= MAX_CYCLES) begin
                        is_cube <= 1'b0;
                        next_state <= FINISH;
                    end else begin
                        n <= n + 4'sd(1);
                        next_state <= CHECK;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    is_cube <= 1'b0;
                end
            endcase
        end
    end

endmodule