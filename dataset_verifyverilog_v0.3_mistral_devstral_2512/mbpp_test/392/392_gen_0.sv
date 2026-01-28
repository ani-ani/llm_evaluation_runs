module max_sum_dp (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [7:0] i;
    reg [15:0] res [0:60];
    reg [15:0] sum_terms;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            i <= 8'd0;
            cycle_count <= 8'd0;
            // Initialize base cases
            res[0] <= 16'd0;
            res[1] <= 16'd1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (n <= 1) begin
                            result <= (n == 0) ? 16'd0 : 16'd1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            i <= 2;
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate sum of terms
                    sum_terms <= res[i >> 1] + res[i / 3] + res[i / 4] + res[i / 5];
                    
                    // Compute and store result for current i
                    if (sum_terms > i)
                        res[i] <= sum_terms;
                    else
                        res[i] <= i;
                    
                    // Check completion or continue
                    if (i == n || cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end else begin
                        i <= i + 1;
                    end
                end

                COMPLETE: begin
                    result <= res[n];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule