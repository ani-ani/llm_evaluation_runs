module TriangularIndexCalculator(
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
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    // Lookup table for 10^(n-1) for n=1 to 9
    reg [15:0] pow10 [0:8];
    integer i;

    // Fixed-point variables (Q16.16 format)
    reg signed [31:0] x;          // Current estimate (Q16.16)
    reg signed [31:0] x_next;     // Next estimate (Q16.16)
    reg signed [31:0] target;     // Target value (Q16.16)
    reg signed [31:0] diff;       // Difference (Q16.16)
    reg signed [31:0] temp;       // Temporary variable

    // Initialize lookup table
    initial begin
        pow10[0] = 16'd1;      // 10^0 = 1
        pow10[1] = 16'd10;     // 10^1 = 10
        pow10[2] = 16'd100;    // 10^2 = 100
        pow10[3] = 16'd1000;   // 10^3 = 1000
        pow10[4] = 16'd10000;  // 10^4 = 10000
        pow10[5] = 16'd100000; // 10^5 = 100000
        pow10[6] = 16'd0;      // 10^6 = 1000000 (too large for 16 bits)
        pow10[7] = 16'd0;      // 10^7
        pow10[8] = 16'd0;      // 10^8
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                if (cycle_count >= MAX_CYCLES - 1) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 32'd0;
            target <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                COMPUTE: begin
                    if (cycle_count == 8'd0) begin
                        // Initialize target = 2 * 10^(n-1) in Q16.16 format
                        if (n > 16'd5) begin
                            target <= 32'd0;  // n > 5, pow10 is 0
                        end else begin
                            target <= pow10[n - 1] << 17;  // Multiply by 2 and shift to Q16.16
                        end
                        // Initial guess: x = target / 2 (Q16.16)
                        x <= target >> 1;
                    end else begin
                        // Newton-Raphson iteration: x_next = (x + target/x) / 2
                        if (x != 32'd0) begin
                            // Compute target / x (Q16.16 division)
                            temp <= {target[31:16], target[15:0]} / x[31:16];
                            // x_next = (x + temp) / 2
                            x_next <= (x + temp) >> 1;
                            // Check for convergence
                            diff <= x_next - x;
                            if (diff < 32'd1 && diff > -32'd1) begin
                                // Converged, round and finish
                                x_next <= x_next + 16'd32768;  // Add 0.5 in Q16.16
                                result <= x_next[31:16];       // Truncate to integer part
                                next_state = DONE_STATE;
                            end else begin
                                x <= x_next;
                            end
                        end
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
                default: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule