module paper_puzzler (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] p_scaled,
    output reg [7:0] n1, n2, n3, n4, n5,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SEARCH  = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10000;

    // Search variables
    reg [7:0] N;           // Total papers (1 to 256)
    reg [7:0] n5_count;    // Count for value 5
    reg [7:0] n4_count;    // Count for value 4
    reg [7:0] n3_count;    // Count for value 3
    reg [7:0] n2_count;    // Count for value 2
    reg [7:0] n1_count;    // Count for value 1 (derived)

    reg [31:0] left_sum;   // Sum of counts*values
    reg [63:0] left_scaled; // left_sum * 10^9
    reg [63:0] right_scaled; // p_scaled * N

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            n1 <= 8'd0;
            n2 <= 8'd0;
            n3 <= 8'd0;
            n4 <= 8'd0;
            n5 <= 8'd0;
            cycle_count <= 8'd0;
            N <= 8'd0;
            n5_count <= 8'd0;
            n4_count <= 8'd0;
            n3_count <= 8'd0;
            n2_count <= 8'd0;
            n1_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SEARCH;
                        N <= 8'd1;
                        n5_count <= 8'd0;
                        n4_count <= 8'd0;
                        n3_count <= 8'd0;
                        n2_count <= 8'd0;
                    end
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Calculate n1 as N - (n5 + n4 + n3 + n2)
                    n1_count <= N - (n5_count + n4_count + n3_count + n2_count);

                    // Calculate left_sum = 5*n5 + 4*n4 + 3*n3 + 2*n2 + 1*n1
                    left_sum <= (5 * n5_count) + (4 * n4_count) + (3 * n3_count) + (2 * n2_count) + (1 * n1_count);

                    // Calculate left_scaled = left_sum * 10^9
                    left_scaled <= {32'd0, left_sum} * 32'd1000000000;

                    // Calculate right_scaled = p_scaled * N
                    right_scaled <= {32'd0, p_scaled} * {32'd0, N};

                    // Check if solution found
                    if (left_scaled == right_scaled) begin
                        n1 <= n1_count;
                        n2 <= n2_count;
                        n3 <= n3_count;
                        n4 <= n4_count;
                        n5 <= n5_count;
                        state <= DONE_STATE;
                    end else begin
                        // Increment counters
                        if (n2_count < N && n3_count + n4_count + n5_count < N) begin
                            n2_count <= n2_count + 8'd1;
                        end else if (n3_count < N && n4_count + n5_count < N) begin
                            n2_count <= 8'd0;
                            n3_count <= n3_count + 8'd1;
                        end else if (n4_count < N && n5_count < N) begin
                            n2_count <= 8'd0;
                            n3_count <= 8'd0;
                            n4_count <= n4_count + 8'd1;
                        end else if (n5_count < N) begin
                            n2_count <= 8'd0;
                            n3_count <= 8'd0;
                            n4_count <= 8'd0;
                            n5_count <= n5_count + 8'd1;
                        end else if (N < 8'd256) begin
                            // Move to next N
                            N <= N + 8'd1;
                            n5_count <= 8'd0;
                            n4_count <= 8'd0;
                            n3_count <= 8'd0;
                            n2_count <= 8'd0;
                        end else begin
                            // No solution found (should not happen for valid P)
                            n1 <= 8'd0;
                            n2 <= 8'd0;
                            n3 <= 8'd0;
                            n4 <= 8'd0;
                            n5 <= 8'd0;
                            state <= DONE_STATE;
                        end
                    end

                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        n1 <= 8'd0;
                        n2 <= 8'd0;
                        n3 <= 8'd0;
                        n4 <= 8'd0;
                        n5 <= 8'd0;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule