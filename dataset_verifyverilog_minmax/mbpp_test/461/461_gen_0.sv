module upper_case_counter(
    input reg [63:0] str_bytes,
    output reg [3:0] count
);
    // Extract each byte
    wire [7:0] byte0 = str_bytes[7:0];
    wire [7:0] byte1 = str_bytes[15:8];
    wire [7:0] byte2 = str_bytes[23:16];
    wire [7:0] byte3 = str_bytes[31:24];
    wire [7:0] byte4 = str_bytes[39:32];
    wire [7:0] byte5 = str_bytes[47:40];
    wire [7:0] byte6 = str_bytes[55:48];
    wire [7:0] byte7 = str_bytes[63:56];

    // Uppercase detection for each byte
    wire is_up0 = (byte0 >= 8'd65) && (byte0 <= 8'd90);
    wire is_up1 = (byte1 >= 8'd65) && (byte1 <= 8'd90);
    wire is_up2 = (byte2 >= 8'd65) && (byte2 <= 8'd90);
    wire is_up3 = (byte3 >= 8'd65) && (byte3 <= 8'd90);
    wire is_up4 = (byte4 >= 8'd65) && (byte4 <= 8'd90);
    wire is_up5 = (byte5 >= 8'd65) && (byte5 <= 8'd90);
    wire is_up6 = (byte6 >= 8'd65) && (byte6 <= 8'd90);
    wire is_up7 = (byte7 >= 8'd65) && (byte7 <= 8'd90);

    // Sum the flags to obtain the count
    always @(*) begin
        count = ({3'b0, is_up0} + {3'b0, is_up1} + {3'b0, is_up2} + {3'b0, is_up3}
                 + {3'b0, is_up4} + {3'b0, is_up5} + {3'b0, is_up6} + {3'b0, is_up7});
    end
endmodule