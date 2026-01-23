module barry_bruce (
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    input [3:0] k_in,
    input [15:0] seq_in,
    input [127:0] costs_in,
    output reg [7:0] min_cost,
    output reg impossible,
    output reg valid
);

reg [3:0] state;
localparam IDLE = 4'd0, SETUP = 4'd1, CHECK = 4'd2, DONE = 4'd3;
reg [15:0] n_val, seq_reg;
reg [3:0] k_val;
reg [127:0] costs_reg;
reg [15:0] min_cost_reg;
reg [15:0] counter;
reg [15:0] current_cost;
reg valid_reg, impossible_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        n_val <= 16'd0;
        seq_reg <= 16'd0;
        k_val <= 4'd0;
        costs_reg <= 128'd0;
        min_cost_reg <= 32767;
        counter <= 16'd0;
        valid_reg <= 1'b0;
        impossible_reg <= 1'b0;
        current_cost <= 16'd0;
    end else begin
        case (state)
            IDLE: if (start) state <= SETUP; else state <= IDLE;
            SETUP: 
                n_val <= n_in;
                seq_reg <= seq_in;
                k_val <= k_in;
                costs_reg <= costs_in;
                counter <= 16'd0;
                min_cost_reg <= 32767;
                state <= CHECK;
            CHECK: 
                if (counter == (1 << n_val)) begin
                    state <= DONE;
                    valid_reg <= 1'b1;
                    if (min_cost_reg == 32767) impossible_reg <= 1'b1;
                    else impossible_reg <= 1'b0;
                    min_cost <= min_cost_reg[7:0];
                end else begin
                    current_cost = 0;
                    if (counter & 1) current_cost += signed'([7:0]) costs_reg[7:0];
                    if (counter & 2) current_cost += signed'([7:0]) costs_reg[15:8];
                    if (counter & 4) current_cost += signed'([7:0]) costs_reg[23:16];
                    if (counter & 8) current_cost += signed'([7:0]) costs_reg[31:24];
                    if (counter & 16) current_cost += signed'([7:0]) costs_reg[39:32];
                    if (counter & 32) current_cost += signed'([7:0]) costs_reg[47:40];
                    if (counter & 64) current_cost += signed'([7:0]) costs_reg[55:48];
                    if (counter & 128) current_cost += signed'([7:0]) costs_reg[63:56];
                    if (counter & 256) current_cost += signed'([7:0]) costs_reg[71:64];
                    if (counter & 512) current_cost += signed'([7:0]) costs_reg[79:72];
                    if (counter & 1024) current_cost += signed'([7:0]) costs_reg[87:80];
                    if (counter & 2048) current_cost += signed'([7:0]) costs_reg[95:88];
                    if (counter & 4096) current_cost += signed'([7:0]) costs_reg[103:96];
                    if (counter & 8192) current_cost += signed'([7:0]) costs_reg[111:104];
                    if (counter & 16384) current_cost += signed'([7:0]) costs_reg[119:112];
                    if (1) begin 
                        if (current_cost < min_cost_reg) begin
                            min_cost_reg <= current_cost;
                        end
                    end
                    counter <= counter + 1;
                    state <= CHECK;
                end
            DONE: valid_reg <= 1'b1;
        endcase
    end
end

assign valid = valid_reg;
assign impossible = impossible_reg;
assign min_cost = min_cost_reg[7:0];

endmodule