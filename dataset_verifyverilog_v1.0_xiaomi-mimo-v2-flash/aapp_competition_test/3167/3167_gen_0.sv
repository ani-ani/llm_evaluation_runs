module range_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1023:0] counts,
    input wire [9:0] L,
    input wire [9:0] R,
    output reg [15:0] result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE_PREFIX = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [9:0] index;           // Index for iterating 0-1023
    reg [15:0] prefix_sum;     // Running prefix sum
    reg [15:0] ps_mem [0:1023]; // Memory to store prefix sums
    reg [15:0] ps_L;           // Stored ps[L]
    reg [15:0] ps_Rplus1;      // Stored ps[R+1]

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 10'd0;
            prefix_sum <= 16'd0;
            ps_L <= 16'd0;
            ps_Rplus1 <= 16'd0;
            // Initialize memory to avoid X
            for (i = 0; i < 1024; i = i + 1) begin
                ps_mem[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE_PREFIX;
                        index <= 10'd0;
                        prefix_sum <= 16'd0;
                    end
                end

                COMPUTE_PREFIX: begin
                    // Compute prefix sum for current index
                    // counts[index] is 1 bit. If 1, add 1 to sum.
                    if (counts[index]) begin
                        prefix_sum <= prefix_sum + 16'd1;
                    end
                    // Store current prefix sum (before increment for next element)
                    // ps[i] represents sum of counts[0] to counts[i-1]
                    // ps[0] = 0. For index 0, ps[0] is stored.
                    ps_mem[index] <= prefix_sum;

                    // Check if we hit L or R+1
                    // We need ps[L] which is sum of counts[0] to counts[L-1]
                    // We need ps[R+1] which is sum of counts[0] to counts[R]
                    // Since we are at 'index', the prefix_sum calculated is for 'index'
                    // (i.e., sum of counts[0..index-1])
                    if (index == L) begin
                        ps_L <= prefix_sum;
                    end
                    if (index == (R + 10'd1)) begin
                        ps_Rplus1 <= prefix_sum;
                    end

                    // Increment index
                    if (index < 10'd1023) begin
                        index <= index + 10'd1;
                    end else begin
                        // Last index 1023 processed. We need ps[1024] as well.
                        // ps[1024] is total sum (prefix_sum after processing 1023)
                        // This will be calculated in the next cycle (after wrap around or finish)
                        // Actually, loop ends here. The state transition handles final calc.
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Finalize calculation
                    // We need ps[R+1]. If R == 1023, R+1 is out of bounds (1024).
                    // ps[1024] is the final prefix_sum (sum of all 1024 counts).
                    if (R == 10'd1023) begin
                        ps_Rplus1 <= prefix_sum;
                    end
                    // Wait one cycle for stability if R was 1023
                    // Then compute result
                    result <= ps_Rplus1 - ps_L;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule