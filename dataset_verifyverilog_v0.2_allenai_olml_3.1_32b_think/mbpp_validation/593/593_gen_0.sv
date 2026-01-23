module ip_remove_leading_zeros (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [119:0] ip_in,
    output reg [119:0] ip_out,
    output reg done
);

localparam IDLE = 2'd0;
localparam PROCESS = 2'd1;
localparam DONE = 2'd2;

reg [1:0] state;
reg [119:0] ip_input_reg;
reg [119:0] ip_out_reg;
reg done_reg;
reg [6:0] counter;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        ip_input_reg <= 120'b0;
        ip_out_reg <= 120'b0;
        done_reg <= 1'b0;
        counter <= 49'd49;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PROCESS;
                    ip_input_reg <= ip_in;
                    counter <= 49'd49;
                end
            end
            PROCESS: begin
                if (counter == 0) begin
                    ip_out_reg <= ip_input_reg;
                    done_reg <= 1'b1;
                    state <= DONE;
                end else begin
                    counter <= counter - 1;
                end
            end
            DONE: begin
            end
        endcase
    end
end

assign ip_out = ip_out_reg;
assign done = done_reg;

endmodule