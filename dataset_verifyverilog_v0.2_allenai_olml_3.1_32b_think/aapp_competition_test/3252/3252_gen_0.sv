module envelope_optimizer (
    input clk,
    input rst_n,
    input start,
    input [15:0] card_width [0:4],
    input [15:0] card_height [0:4],
    input [15:0] card_qty [0:4],
    input [2:0] k_envelopes,
    output reg [31:0] min_waste,
    output reg done
);

    localparam integer IDLE=3'd0, CAPTURE=1, PRECOMPUTE=2, DP_INIT=3, DP_PROCESS=4, DONE=5;
    reg [2:0] state, next_state;

    reg [15:0] card_width_reg [0:4], card_height_reg [0:4], card_qty_reg [0:4];
    reg [2:0] k_envelopes_reg;
    reg [47:0] waste_values [0:31], dp_table [0:31][0:5];
    reg [4:0] precompute_counter;
    reg [31:0] min_waste_reg, total_waste;
    reg done_reg, max_w, max_h;

    assign min_waste = min_waste_reg;
    assign done = done_reg;

    always @(posedge clk) if (!rst_n) begin
        state <= IDLE;
        card_width_reg <= 0; card_height_reg <=0; card_qty_reg <=0; k_envelopes_reg <=0;
        waste_values <=0; dp_table <=0; precompute_counter <=0; min_waste_reg <=0; done_reg <=0;
    end else begin
        case (state)
            IDLE: next_state = start ? CAPTURE : IDLE;
            CAPTURE: begin
                card_width_reg <= card_width; card_height_reg <= card_height; card_qty_reg <= card_qty; k_envelopes_reg <= k_envelopes;
                next_state = PRECOMPUTE;
            end
            PRECOMPUTE: begin
                if (precompute_counter <32) begin
                    max_w=0; max_h=0;
                    if (precompute_counter&1) max_w=card_width_reg[0]; max_h=card_height_reg[0];
                    if (precompute_counter&2) max_w = (card_width_reg[1] > max_w) ? card_width_reg[1] : max_w; max_h = (card_height_reg[1] > max_h) ? card_height_reg[1] : max_h;
                    if (precompute_counter&4) max_w = (card_width_reg[2] > max_w) ? card_width_reg[2] : max_w; max_h = (card_height_reg[2] > max_h) ? card_height_reg[2] : max_h;
                    if (precompute_counter&8) max_w = (card_width_reg[3] > max_w) ? card_width_reg[3] : max_w; max_h = (card_height_reg[3] > max_h) ? card_height_reg[3] : max_h;
                    if (precompute_counter&16) max_w = (card_width_reg[4] > max_w) ? card_width_reg[4] : max_w; max_h = (card_height_reg[4] > max_h) ? card_height_reg[4] : max_h;
                    total_waste=0;
                    if (precompute_counter&1) total_waste += (max_w*max_h - card_width_reg[0]*card_height_reg[0])*card_qty_reg[0];
                    if (precompute_counter&2) total_waste += (max_w*max_h - card_width_reg[1]*card_height_reg[1])*card_qty_reg[1];
                    if (precompute_counter&4) total_waste += (max_w*max_h - card_width_reg[2]*card_height_reg[2])*card_qty_reg[2];
                    if (precompute_counter&8) total_waste += (max_w*max_h - card_width_reg[3]*card_height_reg[3])*card_qty_reg[3];
                    if (precompute_counter&16) total_waste += (max_w*max_h - card_width_reg[4]*card_height_reg[4])*card_qty_reg[4];
                    waste_values[precompute_counter] <= {16'd0, total_waste};
                    precompute_counter <= precompute_counter + 1;
                    next_state = PRECOMPUTE;
                end else next_state=DP_INIT;
            end
            DP_INIT: begin
                dp_table[0][0] <= 48'd0;
                next_state = DP_PROCESS;
            end
            DP_PROCESS: next_state = DONE;
            DONE: begin
                min_waste_reg <= dp_table[31][k_envelopes_reg];
                done_reg <= 1'b1;
            end
        endcase
        state <= next_state;
    end

endmodule