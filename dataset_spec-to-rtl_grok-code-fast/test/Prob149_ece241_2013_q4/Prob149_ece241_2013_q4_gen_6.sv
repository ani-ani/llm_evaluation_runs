module TopModule(
    input clk,
    input reset,
    input [2:0] s,
    output reg fr2,
    output reg fr1,
    output reg fr0,
    output reg dfr
);

    reg [2:0] previous_s;
    reg rising_flag;

    always @(posedge clk)
        if (reset) begin
            previous_s <= 3'b000;
            rising_flag <= 1'b0;
            fr2 <= 1'b1;
            fr1 <= 1'b1;
            fr0 <= 1'b1;
            dfr <= 1'b0;
        end else begin
            if (s != previous_s) begin
                rising_flag <= $countbits(s, '1) > $countbits(previous_s, '1);
                previous_s <= s;
            end
            case (s)
                3'b111: {fr2, fr1, fr0} <= 3'b000;
                3'b011: {fr2, fr1, fr0} <= 3'b001;
                3'b001: {fr2, fr1, fr0} <= 3'b011;
                3'b000: {fr2, fr1, fr0} <= 3'b111;
                default: {fr2, fr1, fr0} <= {fr2, fr1, fr0}; // hold
            endcase
            dfr <= ((s == 3'b011) || (s == 3'b001)) && rising_flag;
        end
endmodule