module LiegesOfLegendre(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire k_parity,
    input wire [3:0] n,
    input wire [15:0] pile_i [0:15],
    output reg [15:0] result,
    output reg done,
    output reg winner
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_GRUNDY = 3'd1;
    localparam [2:0] XOR_REDUCE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    reg [3:0] current_pile_idx;
    reg [15:0] current_pile_size;
    reg [15:0] grundy_number;
    reg [15:0] xor_accumulator;

    // Lookup table for small values (a <= 4)
    localparam [15:0] LUT_ODD_K [0:4] = '{16'd0, 16'd1, 16'd0, 16'd1, 16'd2};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            current_pile_idx <= 4'd0;
            current_pile_size <= 16'd0;
            grundy_number <= 16'd0;
            xor_accumulator <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            winner <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= CALC_GRUNDY;
                        current_pile_idx <= 4'd0;
                        xor_accumulator <= 16'd0;
                        cycle_count <= 8'd0;
                    end
                end

                CALC_GRUNDY: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_pile_idx < n) begin
                        current_pile_size <= pile_i[current_pile_idx];
                        if (k_parity) begin
                            // k is odd
                            if (current_pile_size <= 4) begin
                                grundy_number <= LUT_ODD_K[current_pile_size];
                                next_state <= XOR_REDUCE;
                            end else begin
                                // Iterative division by 2
                                if (current_pile_size[0] == 1'b0) begin
                                    // Even: g(a) = g(a/2)
                                    current_pile_size <= current_pile_size >> 1;
                                end else begin
                                    // Odd: g(a) = g((a-1)/2) XOR 1
                                    current_pile_size <= (current_pile_size - 16'd1) >> 1;
                                    grundy_number <= grundy_number ^ 16'd1;
                                end
                                if (cycle_count >= MAX_CYCLES) begin
                                    next_state <= XOR_REDUCE;
                                end
                            end
                        end else begin
                            // k is even
                            if (current_pile_size >= 16'd3) begin
                                grundy_number <= current_pile_size[0];
                                next_state <= XOR_REDUCE;
                            end else begin
                                grundy_number <= 16'd0;
                                next_state <= XOR_REDUCE;
                            end
                        end
                    end else begin
                        next_state <= FINISH;
                    end
                end

                XOR_REDUCE: begin
                    xor_accumulator <= xor_accumulator ^ grundy_number;
                    current_pile_idx <= current_pile_idx + 4'd1;
                    grundy_number <= 16'd0;
                    cycle_count <= 8'd0;
                    next_state <= CALC_GRUNDY;
                end

                FINISH: begin
                    result <= xor_accumulator;
                    winner <= (xor_accumulator != 16'd0);
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule