module prime_counter (
    input [5:0] n,
    output [7:0] result,
    output valid
);
    reg [7:0] result_reg;
    assign result = result_reg;
    assign valid = 1'b1;
    
    always @(*) begin
        case(n)
            6'd0, 6'd1, 6'd2: result_reg = 8'd0;
            6'd3:             result_reg = 8'd1;
            6'd4:             result_reg = 8'd2;
            6'd5:             result_reg = 8'd2;
            6'd6, 6'd7:       result_reg = 8'd3;
            6'd8:             result_reg = 8'd4;
            6'd9, 6'd10, 6'd11: result_reg = 8'd4;
            6'd12,6'd13,6'd14,6'd15: result_reg = 8'd5;
            6'd16,6'd17:      result_reg = 8'd6;
            6'd18,6'd19:      result_reg = 8'd7;
            6'd20,6'd21:      result_reg = 8'd8;
            6'd22,6'd23,6'd24,6'd25,6'd26,6'd27,6'd28: result_reg = 8'd8;
            6'd29:            result_reg = 8'd9;
            6'd30,6'd31,6'd32,6'd33,6'd34,6'd35,6'd36: result_reg = 8'd10;
            6'd37:            result_reg = 8'd11;
            6'd38,6'd39,6'd40,6'd41: result_reg = 8'd12;
            6'd42,6'd43:      result_reg = 8'd13;
            6'd44,6'd45,6'd46,6'd47: result_reg = 8'd14;
            6'd48,6'd49,6'd50,6'd51,6'd52,6'd53: result_reg = 8'd15;
            6'd54,6'd55,6'd56,6'd57,6'd58,6'd59: result_reg = 8'd16;
            6'd60,6'd61:      result_reg = 8'd17;
            6'd62,6'd63:      result_reg = 8'd18;
            default:           result_reg = 8'd0;
        endcase
    end
endmodule