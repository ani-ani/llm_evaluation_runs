module FragmentAssembly(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] k_values [0:7],
    input wire [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT = 3'd1;
    localparam [2:0] COMPUTE_DIST = 3'd2;
    localparam [2:0] FIND_BRANCH = 3'd3;
    localparam [2:0] MOVING = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Precomputed factorization data
    localparam [5:0] factor [0:16] [0:5] = '
    {
        '0, '0, '0, '0, '0, '0,  // k=0
        '0, '0, '0, '0, '0, '0,  // k=1
        '1, '0, '0, '0, '0, '0,  // k=2
        '0, '1, '0, '0, '0, '0,  // k=3
        '2, '0, '0, '0, '0, '0,  // k=4
        '0, '1, '0, '0, '0, '0,  // k=5
        '1, '1, '0, '0, '0, '0,  // k=6
        '0, '0, '1, '0, '0, '0,  // k=7
        '3, '0, '0, '0, '0, '0,  // k=8
        '0, '2, '0, '0, '0, '0,  // k=9
        '1, '0, '1, '0, '0, '0,  // k=10
        '0, '1, '1, '0, '0, '0,  // k=11
        '2, '1, '0, '0, '0, '0,  // k=12
        '0, '0, '0, '1, '0, '0,  // k=13
        '1, '0, '0, '1, '0, '0,  // k=14
        '0, '1, '0, '1, '0, '0,  // k=15
        '4, '0, '0, '0, '0, '0   // k=16
    };

    // Precomputed dist_to_root
    localparam [4:0] dist_to_root [0:16] = '
    {
        0, 0, 1, 2, 2, 3, 3, 4, 3, 4, 4, 5, 4, 5, 5, 6, 4
    };

    // Prime numbers
    localparam [3:0] primes [0:5] = {2, 3, 5, 7, 11, 13};

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] i, j, k;
    reg [3:0] count [0:16];
    reg [3:0] freq [0:5];
    reg [31:0] total_distance;
    reg [31:0] improved_distance;
    reg [3:0] best_prime;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            for (i = 0; i < 17; i = i + 1) begin
                count[i] <= 4'd0;
            end
            for (i = 0; i < 6; i = i + 1) begin
                freq[i] <= 4'd0;
            end
            total_distance <= 32'd0;
            improved_distance <= 32'd0;
            best_prime <= 4'd0;
            cycle_count <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COUNT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < n) begin
                        count[k_values[i][15:0]] <= count[k_values[i][15:0]] + 4'd1;
                        i <= i + 4'd1;
                        next_state <= COUNT;
                    end else begin
                        i <= 4'd0;
                        next_state <= COMPUTE_DIST;
                    end
                end

                COMPUTE_DIST: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < 17) begin
                        total_distance <= total_distance + (count[i] * dist_to_root[i]);
                        i <= i + 4'd1;
                        next_state <= COMPUTE_DIST;
                    end else begin
                        i <= 4'd0;
                        if (count[1] > (n >> 1)) begin
                            result <= 32'd0;
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= FIND_BRANCH;
                        end
                    end
                end

                FIND_BRANCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < 6) begin
                        freq[i] <= 4'd0;
                        j <= 4'd0;
                        while (j < 17) begin
                            if (factor[j][i] > 0) begin
                                freq[i] <= freq[i] + count[j];
                            end
                            j <= j + 4'd1;
                        end
                        if (freq[i] > (n >> 1)) begin
                            best_prime <= i;
                        end
                        i <= i + 4'd1;
                        next_state <= FIND_BRANCH;
                    end else begin
                        i <= 4'd0;
                        next_state <= MOVING;
                    end
                end

                MOVING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < 17) begin
                        if (factor[i][best_prime] > 0) begin
                            improved_distance <= improved_distance + (count[i] * (dist_to_root[i] - factor[i][best_prime]));
                        end else begin
                            improved_distance <= improved_distance + (count[i] * (dist_to_root[i] + 1));
                        end
                        i <= i + 4'd1;
                        next_state <= MOVING;
                    end else begin
                        result <= improved_distance;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule