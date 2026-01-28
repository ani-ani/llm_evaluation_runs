module scaled_sds(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] r,
    input wire [7:0] m,
    output reg [7:0] n,
    output reg found,
    output reg done
);

    // Parameters
    localparam [7:0] MAX_N = 8'd64;
    localparam [7:0] MAX_M = 8'd256;
    localparam [3:0] VAL_WIDTH = 4'd16;

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] FIND_D = 4'd1;
    localparam [3:0] SEARCH_D = 4'd2;
    localparam [3:0] COMPUTE_A = 4'd3;
    localparam [3:0] UPDATE_VALUE = 4'd4;
    localparam [3:0] UPDATE_DIFF_INIT = 4'd5;
    localparam [3:0] UPDATE_DIFF = 4'd6;
    localparam [3:0] CHECK = 4'd7;
    localparam [3:0] DONE = 4'd8;

    // State register
    reg [3:0] state, next_state;

    // Internal registers
    reg [7:0] sequence [0:63];
    reg [7:0] seen [0:255];
    reg [15:0] A_vals [0:63];
    reg [15:0] prev_A, new_A;
    reg [7:0] d;
    reg [7:0] i;
    reg [15:0] diff;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n <= 8'd0;
            found <= 1'b0;
            done <= 1'b0;
            prev_A <= 16'd0;
            new_A <= 16'd0;
            d <= 8'd0;
            i <= 8'd0;
            diff <= 16'd0;
            cycle_count <= 8'd0;

            // Initialize arrays
            integer j;
            for (j = 0; j < 64; j = j + 1) begin
                sequence[j] <= 8'd0;
                A_vals[j] <= 16'd0;
            end
            for (j = 0; j < 256; j = j + 1) begin
                seen[j] <= 1'b0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize sequence and seen
                        sequence[0] <= r;
                        seen[r] <= 1'b1;
                        n <= 8'd1;
                        prev_A <= r;
                        
                        // Check if r == m
                        if (r == m) begin
                            found <= 1'b1;
                            next_state <= DONE;
                        end else begin
                            next_state <= FIND_D;
                        end
                    end
                end

                FIND_D: begin
                    next_state <= SEARCH_D;
                end

                SEARCH_D: begin
                    // Search for smallest missing integer (1..MAX_M) not in seen
                    integer k;
                    for (k = 1; k <= MAX_M; k = k + 1) begin
                        if (!seen[k]) begin
                            d <= k;
                            break;
                        end
                    end
                    next_state <= COMPUTE_A;
                end

                COMPUTE_A: begin
                    new_A <= prev_A + d;
                    next_state <= UPDATE_VALUE;
                end

                UPDATE_VALUE: begin
                    // Store new_A, increment n, mark seen[new_A]
                    A_vals[n] <= new_A;
                    n <= n + 8'd1;
                    seen[new_A[7:0]] <= 1'b1;
                    
                    // Check if new_A == m
                    if (new_A == m) begin
                        found <= 1'b1;
                        next_state <= DONE;
                    end else begin
                        next_state <= UPDATE_DIFF_INIT;
                    end
                end

                UPDATE_DIFF_INIT: begin
                    i <= 8'd0;
                    next_state <= UPDATE_DIFF;
                end

                UPDATE_DIFF: begin
                    // Compute diff = new_A - A_vals[i]
                    diff <= new_A - A_vals[i];
                    
                    // If diff <= MAX_M, mark seen[diff]
                    if (diff <= MAX_M) begin
                        seen[diff[7:0]] <= 1'b1;
                    end
                    
                    // Check if diff == m
                    if (diff == m) begin
                        found <= 1'b1;
                        next_state <= DONE;
                    end else begin
                        // Increment i
                        i <= i + 8'd1;
                        
                        // If i < n-1, repeat; else go to CHECK
                        if (i < n - 8'd1) begin
                            next_state <= UPDATE_DIFF;
                        end else begin
                            next_state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    // Check if seen[m] == 1
                    if (seen[m]) begin
                        found <= 1'b1;
                        next_state <= DONE;
                    end else if (n < MAX_N) begin
                        // Set prev_A = new_A and go to FIND_D
                        prev_A <= new_A;
                        next_state <= FIND_D;
                    end else begin
                        // n >= MAX_N, go to DONE with found=0
                        found <= 1'b0;
                        next_state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
            
            // Cycle counter for safety
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
            end
        end
    end

endmodule