module char_counter(
    input  [15:0][7:0] str_bytes,
    output reg [3:0]  count
);

    integer i;

    always @* begin
        count = 4'd15; // default if no null found within first 16 bytes
        for (i = 0; i < 16; i = i + 1) begin
            if (str_bytes[i] == 8'h00) begin
                if (i < 15)
                    count = i[3:0];
                else
                    count = 4'd15;
                disable for; // exit loop once first null is found
            end
        end
    end

endmodule