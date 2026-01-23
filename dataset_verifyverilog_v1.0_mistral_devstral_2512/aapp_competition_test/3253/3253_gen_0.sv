module election #(
    parameter MAX_S = 8,
    parameter DATA_WIDTH = 32,
    parameter DELEGATE_WIDTH = 12
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] S,
    input wire [DELEGATE_WIDTH-1:0] D [MAX_S-1:0],
    input wire [DATA_WIDTH-1:0] C [MAX_S-1:0],
    input wire [DATA_WIDTH-1:0] F [MAX_S-1:0],
    input wire [DATA_WIDTH-1:0] U [MAX_S-1:0],
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

    localparam [DATA_WIDTH-1:0] INF = 32'h7FFFFFFF;

    wire [DATA_WIDTH-1:0] cost_wire [MAX_S-1:0];
    genvar i;
    generate
        for (i = 0; i < MAX_S; i = i + 1) begin : gen_cost
            assign cost_wire[i] = calc_cost(C[i], F[i], U[i]);
        end
    endgenerate

    function automatic [DATA_WIDTH-1:0] calc_cost;
        input [DATA_WIDTH-1:0] C_val, F_val, U_val;
        reg [DATA_WIDTH:0] diff;
        begin
            if (C_val > F_val + U_val)
                calc_cost = 32'd0;
            else if (C_val + U_val <= F_val)
                calc_cost = INF;
            else begin
                diff = F_val + U_val - C_val;
                calc_cost = (diff >> 1) + 32'd1;
            end
        end
    endfunction

    wire [DELEGATE_WIDTH-1:0] total_delegates_comb;
    wire [DELEGATE_WIDTH-1:0] required_comb;
    wire [7:0] max_mask_comb;

    assign total_delegates_comb = (S > 0 ? D[0] : 12'd0) + (S > 1 ? D[1] : 12'd0) + (S > 2 ? D[2] : 12'd0) + (S > 3 ? D[3] : 12'd0) + (S > 4 ? D[4] : 12'd0) + (S > 5 ? D[5] : 12'd0) + (S > 6 ? D[6] : 12'd0) + (S > 7 ? D[7] : 12'd0);
    assign required_comb = (total_delegates_comb >> 1) + 12'd1;
    assign max_mask_comb = (8'b00000001 << S) - 8'd1;

    reg [7:0] mask;
    reg [2:0] i_reg;
    reg [DELEGATE_WIDTH-1:0] sum_delegates;
    reg [DATA_WIDTH-1:0] sum_cost;
    reg [DATA_WIDTH-1:0] min_cost;
    reg [DELEGATE_WIDTH-1:0] total_delegates_latched;
    reg [DELEGATE_WIDTH-1:0] required_latched;
    reg [7:0] max_mask_latched;
    reg [3:0] S_latched;
    reg [DELEGATE_WIDTH-1:0] D_latched [MAX_S-1:0];
    reg [DATA_WIDTH-1:0] cost_latched [MAX_S-1:0];

    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_INIT = 3'd1;
    localparam [2:0] S_START_MASK = 3'd2;
    localparam [2:0] S_ADD_STATE = 3'd3;
    localparam [2:0] S_CHECK = 3'd4;
    localparam [2:0] S_DONE = 3'd5;

    reg [2:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= 32'd0;
            mask <= 8'd0;
            i_reg <= 3'd0;
            sum_delegates <= 12'd0;
            sum_cost <= 32'd0;
            min_cost <= INF;
            total_delegates_latched <= 12'd0;
            required_latched <= 12'd0;
            max_mask_latched <= 8'd0;
            S_latched <= 4'd0;
            for (i = 0; i < MAX_S; i = i + 1) begin
                D_latched[i] <= 12'd0;
                cost_latched[i] <= INF;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        S_latched <= S;
                        total_delegates_latched <= total_delegates_comb;
                        required_latched <= required_comb;
                        max_mask_latched <= max_mask_comb;
                        for (i = 0; i < MAX_S; i = i + 1) begin
                            if (i < S) begin
                                D_latched[i] <= D[i];
                                cost_latched[i] <= cost_wire[i];
                            end else begin
                                D_latched[i] <= 12'd0;
                                cost_latched[i] <= INF;
                            end
                        end
                        mask <= 8'd0;
                        min_cost <= INF;
                        state <= S_START_MASK;
                    end
                end

                S_START_MASK: begin
                    i_reg <= 3'd0;
                    sum_delegates <= 12'd0;
                    sum_cost <= 32'd0;
                    state <= S_ADD_STATE;
                end

                S_ADD_STATE: begin
                    if (i_reg < S_latched) begin
                        if (mask[i_reg])
                            sum_delegates <= sum_delegates + D_latched[i_reg];
                        if (mask[i_reg])
                            sum_cost <= sum_cost + cost_latched[i_reg];
                        i_reg <= i_reg + 3'd1;
                        state <= S_ADD_STATE;
                    end else
                        state <= S_CHECK;
                end

                S_CHECK: begin
                    if (sum_delegates >= required_latched) begin
                        if (sum_cost < min_cost)
                            min_cost <= sum_cost;
                    end
                    if (mask < max_mask_latched) begin
                        mask <= mask + 8'd1;
                        state <= S_START_MASK;
                    end else
                        state <= S_DONE;
                end

                S_DONE: begin
                    result <= min_cost;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule