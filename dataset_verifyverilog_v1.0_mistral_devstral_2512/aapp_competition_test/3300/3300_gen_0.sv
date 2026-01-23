module CheetahMinPack #(
    parameter WIDTH = 8,
    parameter STEPS = 257,
    parameter SCALE = 256
)(
    input clk,
    input rst_n,
    input start,
    input [WIDTH-1:0] t0, t1, t2,
    input [WIDTH-1:0] v0, v1, v2,
    output reg [15:0] result,
    output reg done
);

    // Combinational max_t
    wire [WIDTH-1:0] max_t_comb = (t0 > t1) ? ((t0 > t2) ? t0 : t2) : ((t1 > t2) ? t1 : t2);

    // Scaled times
    wire [31:0] t0_scaled = {t0, 8'b0};
    wire [31:0] t1_scaled = {t1, 8'b0};
    wire [31:0] t2_scaled = {t2, 8'b0};

    // Combinational signals for current T
    wire [31:0] D0 = T_reg - t0_scaled;
    wire [31:0] D1 = T_reg - t1_scaled;
    wire [31:0] D2 = T_reg - t2_scaled;

    wire [31:0] P0 = v0 * D0;
    wire [31:0] P1 = v1 * D1;
    wire [31:0] P2 = v2 * D2;

    // Max and min of P0, P1, P2
    wire [31:0] max_P = (P0 > P1) ? ((P0 > P2) ? P0 : P2) : ((P1 > P2) ? P1 : P2);
    wire [31:0] min_P = (P0 < P1) ? ((P0 < P2) ? P0 : P2) : ((P1 < P2) ? P1 : P2);

    wire [31:0] diff = max_P - min_P;

    // State machine
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] LOOP = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state;
    reg [31:0] T_reg;
    reg [31:0] min_pack_reg;
    reg [8:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            T_reg <= 32'd0;
            min_pack_reg <= 32'd0;
            counter <= 9'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    T_reg <= {max_t_comb, 8'b0};
                    min_pack_reg <= 32'hFFFF_FFFF;
                    counter <= 9'd0;
                    state <= LOOP;
                end

                LOOP: begin
                    if (diff < min_pack_reg) begin
                        min_pack_reg <= diff;
                    end

                    T_reg <= T_reg + 32'd1;
                    counter <= counter + 9'd1;

                    if (counter == STEPS - 1) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result <= min_pack_reg[15:0];
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule