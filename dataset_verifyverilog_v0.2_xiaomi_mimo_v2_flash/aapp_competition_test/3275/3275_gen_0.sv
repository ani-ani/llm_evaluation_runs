module art_dealer_count (
    input clk,
    input rst_n,
    input start,
    input [7:0] client_idx,
    input [7:0] a_in,
    input [7:0] b_in,
    output reg [15:0] result,
    output reg done,
    output reg error
);

    // Parameters
    parameter integer MOD = 10007;
    parameter integer NUM_CLIENTS = 8;
    parameter integer IDX_WIDTH = 3; // 2^3 = 8
    parameter integer DATA_WIDTH = 16; // log2(MOD) approx 14 bits

    // State Encoding
    localparam IDLE = 3'b001;
    localparam LOAD = 3'b010;
    localparam COMPUTE = 3'b100;
    localparam DONE = 3'b000;
    reg [2:0] current_state, next_state;

    // Internal Registers
    reg [7:0] a_reg [0:7];
    reg [7:0] b_reg [0:7];

    // Computation Registers
    reg [15:0] prod_ab;
    reg [15:0] prod_b;
    reg [15:0] sum_a_prod_b;

    // Iteration Control
    reg [3:0] iter_count; // 0 to 8
    reg calc_done;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: begin
                if (iter_count >= NUM_CLIENTS) next_state = COMPUTE;
                else next_state = LOAD;
            end
            COMPUTE: begin
                if (calc_done) next_state = IDLE;
                else next_state = COMPUTE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Logic for iter_count
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            iter_count <= 0;
        end else begin
            if (current_state == IDLE && start) begin
                iter_count <= 0;
            end else if (current_state == LOAD) begin
                if (iter_count < NUM_CLIENTS) 
                    iter_count <= iter_count + 1;
            end else if (current_state == COMPUTE) begin
                if (iter_count < NUM_CLIENTS) 
                    iter_count <= iter_count + 1;
                else 
                    iter_count <= 0; // Reset for next run
            end else begin
                iter_count <= 0;
            end
        end
    end

    // Loading Data
    always @(posedge clk) begin
        if (current_state == LOAD && iter_count < NUM_CLIENTS) begin
            a_reg[iter_count[2:0]] <= a_in;
            b_reg[iter_count[2:0]] <= b_in;
        end
    end

    // Computation Logic
    reg [15:0] Acc_A, Acc_B, Acc_S;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Acc_A <= 1;
            Acc_B <= 1;
            Acc_S <= 0;
            calc_done <= 0;
            done <= 0;
            error <= 0;
            result <= 0;
        end else begin
            done <= 0;
            calc_done <= 0;
            error <= 0;

            if (current_state == IDLE && start) begin
                Acc_A <= 1;
                Acc_B <= 1;
                Acc_S <= 0;
            end

            if (current_state == LOAD) begin
                if (a_in == 0 || b_in == 0) error <= 1;
            end

            if (current_state == COMPUTE) begin
                if (iter_count < NUM_CLIENTS) begin
                    Acc_S <= ( (Acc_S * b_reg[iter_count[2:0]]) + (Acc_B * a_reg[iter_count[2:0]]) ) % MOD;
                    Acc_B <= ( Acc_B * b_reg[iter_count[2:0]] ) % MOD;
                    Acc_A <= ( Acc_A * (a_reg[iter_count[2:0]] + b_reg[iter_count[2:0]]) ) % MOD;
                    if (iter_count == NUM_CLIENTS - 1) begin
                        calc_done <= 1;
                    end
                end else begin
                    reg [15:0] diff1, diff2;
                    diff1 = (Acc_A >= Acc_B) ? (Acc_A - Acc_B) : (Acc_A + MOD - Acc_B);
                    diff2 = (diff1 >= Acc_S) ? (diff1 - Acc_S) : (diff1 + MOD - Acc_S);
                    result <= diff2 % MOD;
                    done <= 1;
                    calc_done <= 1;
                end
            end
        end
    end

    // Load Logic Separate
    always @(posedge clk) begin
        if (current_state == LOAD) begin
            a_reg[client_idx[2:0]] <= a_in;
            b_reg[client_idx[2:0]] <= b_in;
        end
    end

endmodule