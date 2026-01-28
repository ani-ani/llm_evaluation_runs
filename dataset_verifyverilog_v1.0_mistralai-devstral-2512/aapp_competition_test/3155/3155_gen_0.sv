module jeopardy_ai(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] X,
    output reg [5:0] n,
    output reg [5:0] k,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_N = 3'd1;
    localparam [2:0] COMPUTE_K = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] UPDATE_BEST = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state;
    reg [5:0] best_n;
    reg [5:0] best_k;
    reg [5:0] current_n;
    reg [5:0] current_k;
    reg [63:0] current_C;
    reg found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2048;

    // Precompute C(64,32) for comparison
    localparam [63:0] MAX_BINOMIAL = 64'd1832624140942590534;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n <= 6'd0;
            k <= 6'd0;
            done <= 1'b0;
            valid <= 1'b0;
            best_n <= 6'd0;
            best_k <= 6'd0;
            current_n <= 6'd0;
            current_k <= 6'd0;
            current_C <= 64'd0;
            found <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Special case: X = 1
                        if (X == 32'd1) begin
                            n <= 6'd0;
                            k <= 6'd0;
                            valid <= 1'b1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else if (X > MAX_BINOMIAL[31:0]) begin
                            // X too large
                            valid <= 1'b0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            // Initialize for search
                            best_n <= 6'd64;
                            best_k <= 6'd32;
                            current_n <= 6'd0;
                            current_k <= 6'd0;
                            current_C <= 64'd0;
                            found <= 1'b0;
                            state <= COMPUTE_N;
                        end
                    end
                end

                COMPUTE_N: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        // Initialize for new n
                        current_k <= 6'd0;
                        current_C <= 64'd1;  // C(n,0) = 1
                        state <= COMPUTE_K;
                    end
                end

                COMPUTE_K: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        // Compute C(n,k) = C(n,k-1) * (n-k+1) / k
                        if (current_k > 6'd0) begin
                            current_C <= current_C * (current_n - current_k + 6'd1) / current_k;
                        end
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        // Check if current_C matches X
                        if (current_C[31:0] == X) begin
                            found <= 1'b1;
                            best_n <= current_n;
                            best_k <= current_k;
                        end
                        
                        // Check if we should stop early
                        if (current_C[31:0] > X || current_C > MAX_BINOMIAL) begin
                            state <= UPDATE_BEST;
                        end else begin
                            // Move to next k
                            if (current_k < (current_n >> 1)) begin
                                current_k <= current_k + 6'd1;
                                state <= COMPUTE_K;
                            end else begin
                                state <= UPDATE_BEST;
                            end
                        end
                    end
                end

                UPDATE_BEST: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        // Move to next n
                        if (current_n < 6'd64) begin
                            current_n <= current_n + 6'd1;
                            state <= COMPUTE_N;
                        end else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    if (found) begin
                        n <= best_n;
                        k <= best_k;
                        valid <= 1'b1;
                    end else begin
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
        end
    end
endmodule