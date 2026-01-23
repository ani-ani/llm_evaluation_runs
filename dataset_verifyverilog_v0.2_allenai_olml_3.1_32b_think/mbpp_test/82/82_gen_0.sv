module sphere_volume (input clk, input rst_n, input start, input [31:0] radius, output reg [31:0] volume, output reg done);

parameter IDLE = 3'd0;
parameter CALC_SQ = 1;
parameter CALC_CUBE = 2;
parameter CALC_FINAL =3;
parameter WAIT1 =4;
parameter WAIT2=5;
parameter DONE_STATE=6;

reg [2:0] state;
reg [31:0] radius_reg;
reg [63:0] reg_sq;
reg [63:0] reg_cube;
reg [63:0] temp;
reg [31:0] internal_volume;
reg internal_done;

parameter C = 32'h0006487E;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        internal_done <=0;
        internal_volume <=0;
        radius_reg <=0;
        reg_sq <=0;
        reg_cube <=0;
        temp <=0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                radius_reg <= radius;
                state <= CALC_SQ;
            end
        end else if (state == CALC_SQ) begin
            reg_sq <= radius_reg * radius_reg;
            state <= CALC_CUBE;
        end else if (state == CALC_CUBE) begin
            reg_cube <= reg_sq[31:0] * radius_reg;
            state <= CALC_FINAL;
        end else if (state == CALC_FINAL) begin
            temp <= reg_cube[31:0] * C;
            internal_volume <= temp[47:16];
            state <= WAIT1;
        end else if (state == WAIT1) begin
            state <= WAIT2;
        end else if (state == WAIT2) begin
            state <= DONE_STATE;
            internal_done <=1;
        end else if (state == DONE_STATE) begin
            internal_done <=1;
        end
    end
end

assign volume = internal_volume;
assign done = internal_done;

endmodule