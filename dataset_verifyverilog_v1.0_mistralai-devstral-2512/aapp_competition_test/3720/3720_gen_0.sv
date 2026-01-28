module powers_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] n_in,
    output reg done,
    output reg winner
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] CHECK_BASE = 3'd2;
    localparam [2:0] CHECK_POWER = 3'd3;
    localparam [2:0] COUNT_CHAIN = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state;
    reg [31:0] n;
    reg [31:0] base;
    reg [31:0] power;
    reg [31:0] chain_length;
    reg [31:0] xor_sum;
    reg [31:0] sqrt_n;
    reg [31:0] temp;
    reg [31:0] i;
    reg [31:0] j;
    reg is_power;
    reg [31:0] max_base;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n <= 32'd0;
            base <= 32'd0;
            power <= 32'd0;
            chain_length <= 32'd0;
            xor_sum <= 32'd0;
            sqrt_n <= 32'd0;
            temp <= 32'd0;
            i <= 32'd0;
            j <= 32'd0;
            is_power <= 1'b0;
            max_base <= 32'd0;
            done <= 1'b0;
            winner <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    n <= n_in;
                    xor_sum <= 32'd0;
                    // Handle number 1 separately
                    if (n >= 1) begin
                        xor_sum <= xor_sum ^ 32'd1;
                    end
                    // Calculate sqrt(n)
                    sqrt_n <= 32'd0;
                    temp <= 32'd0;
                    for (i = 0; i < 32; i = i + 1) begin
                        if ((temp + 32'd1) * (temp + 32'd1) <= n) begin
                            temp <= temp + 32'd1;
                        end
                    end
                    sqrt_n <= temp;
                    base <= 32'd2;
                    state <= CHECK_BASE;
                end

                CHECK_BASE: begin
                    if (base > sqrt_n) begin
                        state <= FINISH;
                    end else begin
                        // Check if base is a power of a smaller number
                        is_power <= 1'b0;
                        i <= 32'd2;
                        j <= 32'd2;
                        state <= CHECK_POWER;
                    end
                end

                CHECK_POWER: begin
                    if (is_power) begin
                        base <= base + 32'd1;
                        state <= CHECK_BASE;
                    end else if (i > sqrt_n) begin
                        // Not a power, count chain
                        chain_length <= 32'd1;
                        power <= base * base;
                        state <= COUNT_CHAIN;
                    end else if (j > 32) begin
                        i <= i + 32'd1;
                        j <= 32'd2;
                    end else begin
                        temp <= 1;
                        for (j = 1; j < 32; j = j + 1) begin
                            temp <= temp * i;
                            if (temp == base) begin
                                is_power <= 1'b1;
                            end
                            if (temp > base) begin
                                break;
                            end
                        end
                        i <= i + 32'd1;
                        j <= 32'd2;
                    end
                end

                COUNT_CHAIN: begin
                    if (power > n) begin
                        // Add to XOR sum
                        xor_sum <= xor_sum ^ (chain_length % 2);
                        base <= base + 32'd1;
                        state <= CHECK_BASE;
                    end else begin
                        chain_length <= chain_length + 32'd1;
                        power <= power * base;
                    end
                end

                FINISH: begin
                    // Determine winner
                    if (xor_sum != 0) begin
                        winner <= 1'b1; // Vasya wins
                    end else begin
                        winner <= 1'b0; // Petya wins
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule