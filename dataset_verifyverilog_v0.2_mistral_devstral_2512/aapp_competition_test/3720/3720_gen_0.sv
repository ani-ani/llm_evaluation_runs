module powers_game (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg winner,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        CHECK_BASE,
        COMPUTE_CHAIN,
        UPDATE_XOR,
        COUNT_REMAINING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] base;
    reg [7:0] chain_length;
    reg [7:0] xor_result;
    reg [7:0] remaining_count;
    reg [7:0] power_count;
    reg [7:0] temp_power;
    reg [7:0] i;
    reg [7:0] j;
    reg [7:0] max_power;
    reg [7:0] last_power;
    reg [7:0] grundy_value;
    reg is_power;

    // Grundy LUT
    reg [2:0] grundy_lut [0:7];

    // Initialize Grundy LUT
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grundy_lut[0] <= 3'd1; // length 1
            grundy_lut[1] <= 3'd2; // length 2
            grundy_lut[2] <= 3'd1; // length 3
            grundy_lut[3] <= 3'd4; // length 4
            grundy_lut[4] <= 3'd3; // length 5
            grundy_lut[5] <= 3'd2; // length 6
            grundy_lut[6] <= 3'd1; // length 7
            grundy_lut[7] <= 3'd5; // length 8
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            base <= 8'd0;
            chain_length <= 8'd0;
            xor_result <= 8'd0;
            remaining_count <= 8'd0;
            power_count <= 8'd0;
            temp_power <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            max_power <= 8'd0;
            last_power <= 8'd0;
            grundy_value <= 8'd0;
            is_power <= 1'b0;
            winner <= 1'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_BASE;
                    base = 8'd2;
                    i = 8'd2;
                    xor_result = 8'd0;
                    power_count = 8'd0;
                    max_power = 8'd0;
                end else begin
                    next_state = IDLE;
                end
            end

            CHECK_BASE: begin
                if (i > 8'd15) begin
                    next_state = COUNT_REMAINING;
                end else begin
                    next_state = COMPUTE_CHAIN;
                end
            end

            COMPUTE_CHAIN: begin
                next_state = UPDATE_XOR;
            end

            UPDATE_XOR: begin
                next_state = CHECK_BASE;
                i = i + 8'd1;
                base = i;
            end

            COUNT_REMAINING: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                // No operation
            end

            CHECK_BASE: begin
                // Check if base is a perfect power
                is_power = 1'b0;
                for (j = 2; j <= 8'd15; j = j + 1) begin
                    temp_power = j;
                    while (temp_power <= base) begin
                        if (temp_power == base) begin
                            is_power = 1'b1;
                        end
                        temp_power = temp_power * j;
                    end
                end
            end

            COMPUTE_CHAIN: begin
                if (!is_power) begin
                    // Compute chain length
                    chain_length = 8'd0;
                    temp_power = base;
                    while (temp_power <= n) begin
                        chain_length = chain_length + 8'd1;
                        temp_power = temp_power * base;
                    end
                    chain_length = chain_length - 8'd1;
                    power_count = power_count + chain_length;
                    if (temp_power / base > max_power) begin
                        max_power = temp_power / base;
                    end
                end else begin
                    chain_length = 8'd0;
                end
            end

            UPDATE_XOR: begin
                if (chain_length > 8'd0 && chain_length <= 8'd8) begin
                    grundy_value = grundy_lut[chain_length - 1];
                    xor_result = xor_result ^ grundy_value;
                end
            end

            COUNT_REMAINING: begin
                remaining_count = n - max_power - (i - 2);
                if (remaining_count % 2 == 1) begin
                    xor_result = xor_result ^ 1;
                end
            end

            DONE: begin
                winner = (xor_result != 0);
                done = 1'b1;
            end

            default: begin
                // No operation
            end
        endcase
    end

endmodule