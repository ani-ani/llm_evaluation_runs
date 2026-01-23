module powers_game (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg winner,
    output reg done
);

// State definitions
localparam IDLE = 3'b000;
localparam CHECK_BASE = 3'b001;
localparam COMPUTE_CHAIN = 3'b010;
localparam UPDATE_XOR = 3'b011;
localparam COUNT_REMAINING = 3'b100;
localparam DONE = 3'b101;

// Registers
reg [2:0] state, next_state;
reg [7:0] i; // base iterator (2 to 15)
reg [7:0] power;
reg [7:0] next_power;
reg [7:0] count;
reg [2:0] chain_len;
reg [2:0] grundy_val;
reg [7:0] xor_result;
reg [7:0] total_count;
reg is_power;
reg [7:0] sqrt_limit;
reg [7:0] max_power;

// Next state logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// State transition logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start)
                next_state = CHECK_BASE;
            else
                next_state = IDLE;
        end

        CHECK_BASE: begin
            if (i > 15 || i > n)
                next_state = COUNT_REMAINING;
            else
                next_state = COMPUTE_CHAIN;
        end

        COMPUTE_CHAIN: begin
            if (is_power || power > n || chain_len > 8)
                next_state = CHECK_BASE;
            else
                next_state = COMPUTE_CHAIN;
        end

        UPDATE_XOR: begin
            next_state = CHECK_BASE;
        end

        COUNT_REMAINING: begin
            next_state = DONE;
        end

        DONE: begin
            if (start)
                next_state = IDLE;
            else
                next_state = DONE;
        end

        default: next_state = IDLE;
    endcase
end

// Check if base i is a perfect power of smaller number
always @(*) begin
    is_power = 1'b0;
    // Check if i is a power of numbers from 2 to sqrt(i)
    // Simplified: check squares, cubes up to i^(1/3)
    if (i > 3) begin
        // Check square
        if (i >= 4 && i[0] == 0) begin // even numbers
            if (i == 4 || i == 9 || i == 16 || i == 25 || i == 36 || i == 49 ||
                i == 64 || i == 81 || i == 100 || i == 121 || i == 144 || i == 169 ||
                i == 196 || i == 225 || i == 256)
                is_power = 1'b1;
        end
        // Check cube
        if (i == 8 || i == 27 || i == 64 || i == 125 || i == 216)
            is_power = 1'b1;
        // Check 4th powers and higher (rare for n<=256)
        if (i == 16 || i == 81 || i == 256)
            is_power = 1'b1;
    end
end

// Compute chain length and Grundy value
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        power <= 1;
        chain_len <= 0;
        grundy_val <= 0;
        max_power <= 0;
    end else if (state == CHECK_BASE) begin
        // Initialize for new base
        power <= i;
        chain_len <= 1;
        // Set max_power to track highest power in current chain
        max_power <= i;
    end else if (state == COMPUTE_CHAIN && !is_power && power <= n && chain_len <= 8) begin
        // Multiply power by base i
        if (power * i <= n && power * i > power) begin
            power <= power * i;
            chain_len <= chain_len + 1;
            max_power <= power * i;
        end
    end
end

// Grundy LUT
always @(*) begin
    case (chain_len)
        1: grundy_val = 1;
        2: grundy_val = 2;
        3: grundy_val = 1;
        4: grundy_val = 4;
        5: grundy_val = 3;
        6: grundy_val = 2;
        7: grundy_val = 1;
        8: grundy_val = 5;
        default: grundy_val = 0;
    endcase
end

// Update XOR and counters
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        xor_result <= 0;
        total_count <= 0;
        i <= 2;
        winner <= 0;
        done <= 0;
    end else begin
        case (state)
            IDLE: begin
                xor_result <= 0;
                total_count <= 0;
                i <= 2;
                done <= 0;
            end

            UPDATE_XOR: begin
                if (!is_power && chain_len >= 1 && chain_len <= 8) begin
                    xor_result <= xor_result ^ grundy_val;
                    total_count <= total_count + chain_len;
                end
                i <= i + 1;
            end

            CHECK_BASE: begin
                // Just moving to next state, i handled in UPDATE_XOR or here
                if (i <= 15 && i <= n && !is_power && (state != UPDATE_XOR)) begin
                    // This handles increment when skipping powers
                    i <= i + 1;
                end
            end

            COUNT_REMAINING: begin
                // Count remaining numbers
                if (n > total_count) begin
                    // XOR with parity of remaining count
                    if ((n - total_count) % 2 == 1)
                        xor_result <= xor_result ^ 1;
                end
            end

            DONE: begin
                winner <= (xor_result != 0);
                done <= 1'b1;
            end
        endcase
    end
end

// Fix CHECK_BASE logic to handle increment properly
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i <= 2;
    end else if (state == CHECK_BASE) begin
        if (i <= 15 && i <= n) begin
            if (is_power) begin
                i <= i + 1; // Skip perfect powers
            end
        end
    end else if (state == UPDATE_XOR) begin
        i <= i + 1; // Increment after processing
    end else if (state == IDLE) begin
        i <= 2;
    end
end

endmodule