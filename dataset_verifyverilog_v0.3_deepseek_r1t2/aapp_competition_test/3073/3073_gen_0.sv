module tarot_knight_min_cost #(
    parameter MAX_CARDS = 4,
    parameter COORD_WIDTH = 8,
    parameter VAL_WIDTH = 8,
    parameter PRICE_WIDTH = 16,
    parameter RESULT_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire signed [COORD_WIDTH-1:0] card_r [0:MAX_CARDS-1],
    input wire signed [COORD_WIDTH-1:0] card_c [0:MAX_CARDS-1],
    input wire [VAL_WIDTH-1:0] card_a [0:MAX_CARDS-1],
    input wire [VAL_WIDTH-1:0] card_b [0:MAX_CARDS-1],
    input wire [PRICE_WIDTH-1:0] card_p [0:MAX_CARDS-1],
    input wire [3:0] num_cards,
    
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

localparam [2:0] IDLE = 3'd0;
localparam [2:0] CHECK_SUBSET = 3'd1;
localparam [2:0] CALC_COST = 3'd2;
localparam [2:0] UPDATE_MIN = 3'd3;
localparam [2:0] NEXT_SUBSET = 3'd4;
localparam [2:0] FINISHED = 3'd5;

reg [2:0] state;
reg [MAX_CARDS-1:0] subset;
reg [RESULT_WIDTH-1:0] min_cost;
reg [RESULT_WIDTH-1:0] current_cost;
reg subset_valid;

wire signed [COORD_WIDTH-1:0] start_r = card_r[0];
wire signed [COORD_WIDTH-1:0] start_c = card_c[0];

integer i;
generate
    if (MAX_CARDS > 0) begin
        always @(*) begin
            reg first_gcd;
            integer gcd_val;
            integer card_gcd;
            integer target_r;
            integer target_c;
            
            subset_valid = 1'b0;
            current_cost = {RESULT_WIDTH{1'b0}};
            
            if (subset[0] == 1'b0) begin
                subset_valid = 1'b0;
            end else begin
                first_gcd = 1'b1;
                current_cost = {RESULT_WIDTH{1'b0}};
                
                for (i = 0; i < MAX_CARDS; i = i + 1) begin
                    if (i < num_cards && subset[i]) begin
                        current_cost = current_cost + card_p[i];
                        
                        if (first_gcd) begin
                            gcd_val = gcd_full(card_a[i], card_b[i]);
                            first_gcd = 1'b0;
                        end else begin
                            card_gcd = gcd_full(card_a[i], card_b[i]);
                            gcd_val = gcd_full(gcd_val, card_gcd);
                        end
                    end
                end
                
                if (!first_gcd) begin
                    target_r = (start_r < 0) ? -start_r : start_r;
                    target_c = (start_c < 0) ? -start_c : start_c;
                    
                    if ((target_r % gcd_val == 0) && (target_c % gcd_val == 0)) begin
                        subset_valid = 1'b1;
                    end
                end
            end
        end
    end
endgenerate

function automatic integer gcd_full(input integer a, input integer b);
    integer t;
    begin
        a = (a < 0) ? -a : a;
        b = (b < 0) ? -b : b;
        if (a == 0) gcd_full = b;
        else if (b == 0) gcd_full = a;
        else begin
            while (b != 0) begin
                t = b;
                b = a % b;
                a = t;
            end
            gcd_full = a;
        end
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        subset <= {MAX_CARDS{1'b0}};
        min_cost <= {RESULT_WIDTH{1'b1}};
        result <= {RESULT_WIDTH{1'b0}};
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start && (num_cards > 0)) begin
                    subset <= {{MAX_CARDS-1{1'b0}}, 1'b1};
                    min_cost <= {RESULT_WIDTH{1'b1}};
                    state <= CHECK_SUBSET;
                end
            end
            
            CHECK_SUBSET: begin
                if (subset < (1 << num_cards)) begin
                    state <= (subset_valid) ? CALC_COST : NEXT_SUBSET;
                end else begin
                    state <= FINISHED;
                end
            end
            
            CALC_COST: begin
                state <= UPDATE_MIN;
            end
            
            UPDATE_MIN: begin
                if (current_cost < min_cost) begin
                    min_cost <= current_cost;
                end
                state <= NEXT_SUBSET;
            end
            
            NEXT_SUBSET: begin
                subset <= subset + 1'b1;
                state <= CHECK_SUBSET;
            end
            
            FINISHED: begin
                result <= (min_cost == {RESULT_WIDTH{1'b1}}) ? {RESULT_WIDTH{1'b1}} : min_cost;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule