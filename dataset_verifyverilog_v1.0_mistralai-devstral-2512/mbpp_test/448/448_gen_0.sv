module PerrinSum(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // Register declarations
    reg [1:0] state;
    reg [15:0] a, b, c;  // P(n-3), P(n-2), P(n-1)
    reg [15:0] sum;
    reg [3:0] counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            a <= 16'd0;
            b <= 16'd0;
            c <= 16'd0;
            sum <= 16'd0;
            counter <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize for computation
                        case (n)
                            4'd0: begin
                                result <= 16'd3;
                                state <= FINISH;
                            end
                            4'd1: begin
                                result <= 16'd3;
                                state <= FINISH;
                            end
                            4'd2: begin
                                result <= 16'd5;
                                state <= FINISH;
                            end
                            default: begin
                                // n >= 3
                                a <= 16'd3;  // P(0)
                                b <= 16'd0;  // P(1)
                                c <= 16'd2;  // P(2)
                                sum <= 16'd5;  // P(0)+P(1)+P(2)
                                counter <= n - 4'd3;  // Remaining iterations
                                state <= COMPUTE;
                            end
                        endcase
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute next Perrin number
                    a <= b;
                    b <= c;
                    c <= a + b;
                    
                    // Add to sum
                    sum <= sum + c;
                    
                    // Decrement counter
                    counter <= counter - 4'd1;
                    
                    // Check if done
                    if (counter == 4'd0 || cycle_count >= MAX_CYCLES) begin
                        result <= sum;
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