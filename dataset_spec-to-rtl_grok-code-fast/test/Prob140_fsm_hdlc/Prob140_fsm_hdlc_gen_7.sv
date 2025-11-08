module TopModule(
    input clk,
    input reset,
    input in,
    output reg disc,
    output reg flag,
    output reg err
);
    reg [3:0] counter;
    reg disc_next;
    reg flag_next;
    reg err_next;
    always_ff @(posedge clk) begin
        if (reset) begin
            counter <= 4'd0;
            disc_next <= 0;
            flag_next <= 0;
            err_next <= 0;
            disc <= 0;
            flag <= 0;
            err <= 0;
        end else begin
            disc_next <= 0;
            flag_next <= 0;
            err_next <= 0;
            disc <= disc_next;
            flag <= flag_next;
            err <= err_next;
            if (in == 0) begin
                counter <= 4'd0;
                if (counter == 4'd5) disc_next <= 1'b1;
            end else begin
                if (counter < 4'd7) counter <= counter + 4'd1;
                if (counter == 4'd6) err_next <= 1'b1;
            end
            if (counter == 4'd6 && in == 0) flag_next <= 1'b1;
        end
    end
endmodule