module shuttle_optimizer (
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    input [2:0] k_in,
    input [15:0] t_in [0:15],
    output reg [31:0] min_time,
    output reg done
);

reg [31:0] t_values [0:15];
reg [4:0] n, k;
reg [4:0] people_home;
reg [2:0] cars_at_home;
reg [31:0] current_time;
reg [3:0] next_driver_idx;
reg [2:0] state;
reg done_reg;

always_ff @(posedge clk)
begin
    if (!rst_n) begin
        n <= 5'b0;
        k <= 3'b0;
        people_home <= 5'b0;
        cars_at_home <= 3'b0;
        current_time <= 32'b0;
        next_driver_idx <= 4'b0;
        state <= 2'b00;
        done_reg <= 1'b0;
        t_values <= 32'b0;
    end else begin
        case (state)
            2'b00: begin
                if (start)
                    state <= 2'b01;
            end
            2'b01: state <= 2'b10;
            2'b10: state <= 2'b11;
            2'b11: ;
        endcase
    end
end

assign done = done_reg;

endmodule