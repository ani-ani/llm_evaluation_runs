module explosion_probability (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] m,
    input [6:0] damage,
    input [5:0] my_minions_health [0:4],
    input [5:0] opp_minions_health [0:4],
    output reg [31:0] probability,
    output reg done
);

reg [2:0] state;
localparam IDLE = 3'd0, COMPUTE_PROB = 3'd1, DONE = 3'd2;

reg [2:0] n_reg, m_reg;
reg [6:0] damage_reg;
reg [5:0] my_minions_health_reg [0:4];
reg [5:0] opp_minions_health_reg [0:4];
reg [31:0] prob_reg;
reg done_reg;
reg [10:0] cycle_count;

wire [10:0] total_opp_health;
assign total_opp_health = opp_minions_health_reg[0] + opp_minions_health_reg[1] + opp_minions_health_reg[2] + opp_minions_health_reg[3] + opp_minions_health_reg[4];

always_ff @(posedge clk)
if (!rst_n) begin
    state <= IDLE;
    n_reg <= 3'd0; m_reg <=3'd0; damage_reg <=8'd0;
    my_minions_health_reg <= {5{6'd0}}; 
    opp_minions_health_reg <= {5{6'd0}};
    prob_reg <= 32'd0;
    done_reg <= 1'b0;
    cycle_count <= 16'd0;
end
else begin
    case (state)
        IDLE: begin
            if (start) begin
                n_reg <= n;
                m_reg <= m;
                damage_reg <= damage;
                my_minions_health_reg <= my_minions_health;
                opp_minions_health_reg <= opp_minions_health;
                state <= COMPUTE_PROB;
            end
        end
        COMPUTE_PROB: begin
            if (cycle_count < 100) begin
                cycle_count <= cycle_count +1;
            end else begin
                if (damage_reg >= total_opp_health) begin
                    prob_reg <= 32'h8000; 
                end else begin
                    prob_reg <= 32'h0000; 
                end
                done_reg <= 1'b1;
                state <= DONE;
                cycle_count <= 16'd0;
            end
        end
        DONE: begin
        end
    endcase
end

assign probability = prob_reg;
assign done = done_reg;

endmodule