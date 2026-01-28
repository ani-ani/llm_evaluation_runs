module cube_sum_even(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [3:0] i;  // Iteration counter
    reg [31:0] sum;  // Accumulated sum
    reg [31:0] current_term;  // Current term (2*i)^3
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i <= 4'd0;
            sum <= 32'd0;
            current_term <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 4'd1;  // Start from i=1
                        sum <= 32'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute current term: (2*i)^3
                    current_term <= (2 * i) * (2 * i) * (2 * i);

                    // Accumulate sum
                    sum <= sum + current_term;

                    // Check if done with iterations
                    if (i == n || n == 4'd0) begin
                        state <= FINISH;
                    end else begin
                        i <= i + 4'd1;
                    end
                end

                FINISH: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule