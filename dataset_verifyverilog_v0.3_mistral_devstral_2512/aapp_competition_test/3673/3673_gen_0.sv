module arrow_permutation(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [7:0] K,
    output reg [3:0] b_0,
    output reg [3:0] b_1,
    output reg [3:0] b_2,
    output reg [3:0] b_3,
    output reg [3:0] b_4,
    output reg [3:0] b_5,
    output reg [3:0] b_6,
    output reg [3:0] b_7,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] COMPUTE_GCD    = 3'd1;
    localparam [2:0] COMPUTE_INVERSE = 3'd2;
    localparam [2:0] ASSIGN_B       = 3'd3;
    localparam [2:0] DONE_STATE     = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] gcd_result;
    reg [3:0] s;  // modular inverse
    reg [3:0] i;  // loop counter
    reg [3:0] temp_a, temp_b;  // temporary for gcd
    reg [3:0] temp_s;  // temporary for inverse
    reg [3:0] mod_result;  // temporary for modulo
    reg [7:0] cycle_count;  // prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            gcd_result <= 4'd0;
            s <= 4'd0;
            i <= 4'd0;
            temp_a <= 4'd0;
            temp_b <= 4'd0;
            temp_s <= 4'd0;
            mod_result <= 4'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            b_0 <= 4'd0;
            b_1 <= 4'd0;
            b_2 <= 4'd0;
            b_3 <= 4'd0;
            b_4 <= 4'd0;
            b_5 <= 4'd0;
            b_6 <= 4'd0;
            b_7 <= 4'd0;
        end else begin
            state <= next_state;
            if (state == IDLE) begin
                done <= 1'b0;
                impossible <= 1'b0;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_GCD;
                end
            end

            COMPUTE_GCD: begin
                // Compute gcd(N, K) using Euclidean algorithm
                if (i == 4'd0) begin
                    temp_a = N;
                    temp_b = K[3:0];  // Use lower 4 bits of K
                end
                if (temp_a == temp_b) begin
                    gcd_result = temp_a;
                    i = 4'd0;
                    next_state = COMPUTE_INVERSE;
                end else if (temp_a > temp_b) begin
                    temp_a = temp_a - temp_b;
                end else begin
                    temp_b = temp_b - temp_a;
                end
            end

            COMPUTE_INVERSE: begin
                // Check if gcd is 1
                if (gcd_result != 4'd1) begin
                    impossible = 1'b1;
                    next_state = DONE_STATE;
                end else begin
                    // Brute-force search for modular inverse s
                    if (i == 4'd0) begin
                        temp_s = 4'd1;
                    end
                    // Compute (temp_s * K) mod N
                    mod_result = 4'd0;
                    for (int j = 0; j < K; j = j + 1) begin
                        mod_result = mod_result + temp_s;
                        if (mod_result >= N) begin
                            mod_result = mod_result - N;
                        end
                    end
                    if (mod_result == 4'd1) begin
                        s = temp_s;
                        i = 4'd0;
                        next_state = ASSIGN_B;
                    end else begin
                        temp_s = temp_s + 4'd1;
                        if (temp_s >= N) begin
                            impossible = 1'b1;
                            next_state = DONE_STATE;
                        end
                    end
                end
            end

            ASSIGN_B: begin
                // Compute b_i = ((i + s) mod N) + 1
                if (i < N) begin
                    mod_result = i + s;
                    if (mod_result >= N) begin
                        mod_result = mod_result - N;
                    end
                    case (i)
                        4'd0: b_0 = mod_result + 4'd1;
                        4'd1: b_1 = mod_result + 4'd1;
                        4'd2: b_2 = mod_result + 4'd1;
                        4'd3: b_3 = mod_result + 4'd1;
                        4'd4: b_4 = mod_result + 4'd1;
                        4'd5: b_5 = mod_result + 4'd1;
                        4'd6: b_6 = mod_result + 4'd1;
                        4'd7: b_7 = mod_result + 4'd1;
                    endcase
                    i = i + 4'd1;
                end else begin
                    i = 4'd0;
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                    cycle_count <= 8'd0;
                end
            end else begin
                cycle_count <= 8'd0;
            end
        end
    end

endmodule