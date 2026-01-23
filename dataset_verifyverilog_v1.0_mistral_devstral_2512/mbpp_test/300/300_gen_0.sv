module binary_seq_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_N = 4'd8;
    localparam [3:0] DATA_WIDTH = 4'd16;
    localparam [3:0] N_WIDTH = 4'd4;

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] r_reg, r_next;
    reg [3:0] n_reg;
    reg [31:0] nCr_reg, nCr_next;
    reg [31:0] res_reg, res_next;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            r_reg <= 4'd0;
            nCr_reg <= 32'd0;
            res_reg <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            r_reg <= r_next;
            nCr_reg <= nCr_next;
            res_reg <= res_next;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        r_next = r_reg;
        nCr_next = nCr_reg;
        res_next = res_reg;

        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = CALC;
                    n_reg = n_in;
                    r_next = 4'd1;
                    nCr_next = 32'd1;
                    res_next = 32'd1;
                    cycle_count = 8'd0;
                end
            end

            CALC: begin
                if (r_reg == n_reg) begin
                    next_state = DONE;
                end else begin
                    r_next = r_reg + 4'd1;
                    nCr_next = (nCr_reg * (n_reg + 4'd1 - r_reg)) / r_next;
                    res_next = res_reg + nCr_next * nCr_next;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(*) begin
        result = 16'd0;
        done = 1'b0;

        if (state == DONE) begin
            result = res_reg[15:0];
            done = 1'b1;
        end
    end

endmodule