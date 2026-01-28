module BrazilianFactorial(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [31:0] result,
    output reg overflow,
    output reg done
);

    // Precomputed factorials 1! to 12!
    localparam [31:0] FACT_1  = 32'd1;
    localparam [31:0] FACT_2  = 32'd2;
    localparam [31:0] FACT_3  = 32'd6;
    localparam [31:0] FACT_4  = 32'd24;
    localparam [31:0] FACT_5  = 32'd120;
    localparam [31:0] FACT_6  = 32'd720;
    localparam [31:0] FACT_7  = 32'd5040;
    localparam [31:0] FACT_8  = 32'd40320;
    localparam [31:0] FACT_9  = 32'd362880;
    localparam [31:0] FACT_10 = 32'd3628800;
    localparam [31:0] FACT_11 = 32'd39916800;
    localparam [31:0] FACT_12 = 32'd479001600;

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] current_n;
    reg [31:0] product;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Factorial lookup (combinational)
    wire [31:0] fact_lookup;
    always @(*) begin
        case (current_n)
            1'd1:  fact_lookup = FACT_1;
            2'd2:  fact_lookup = FACT_2;
            3'd3:  fact_lookup = FACT_3;
            4'd4:  fact_lookup = FACT_4;
            5'd5:  fact_lookup = FACT_5;
            6'd6:  fact_lookup = FACT_6;
            7'd7:  fact_lookup = FACT_7;
            8'd8:  fact_lookup = FACT_8;
            9'd9:  fact_lookup = FACT_9;
            10'd10: fact_lookup = FACT_10;
            11'd11: fact_lookup = FACT_11;
            12'd12: fact_lookup = FACT_12;
            default: fact_lookup = 32'd0;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'd0;
            overflow <= 1'b0;
            done <= 1'b0;
            current_n <= 8'd0;
            product <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (n == 8'd0) begin
                            result <= 32'd1;
                            done <= 1'b1;
                            next_state <= IDLE;
                        end else if (n > 12'd12) begin
                            result <= 32'd0;
                            overflow <= 1'b1;
                            done <= 1'b1;
                            next_state <= IDLE;
                        end else begin
                            current_n <= n;
                            product <= 32'd1;
                            next_state <= COMPUTE;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_n == 8'd1) begin
                        result <= product;
                        next_state <= DONE_STATE;
                    end else begin
                        product <= product * fact_lookup;
                        current_n <= current_n - 8'd1;
                        if (cycle_count >= MAX_CYCLES) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= COMPUTE;
                        end
                    end
                end

                DONE_STATE: begin
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