module flip_case (
    input [127:0] string_in,
    output reg [127:0] string_out
);
    integer i;
    
    always @* begin
        string_out = string_in; // Default to unchanged
        for (i = 0; i < 16; i = i + 1) begin
            case (string_in[8*i+7:8*i])
                8'h61..8'h7A: string_out[8*i+7:8*i] = string_in[8*i+7:8*i] ^ 8'h20; // lowercase to uppercase
                8'h41..8'h5A: string_out[8*i+7:8*i] = string_in[8*i+7:8*i] ^ 8'h20; // uppercase to lowercase
                default: ; // non-alphabetic unchanged
            endcase
        end
    end
endmodule