module planet_filter(
    input [7:0] planet1_char0,
    input [7:0] planet1_char1,
    input [7:0] planet1_char2,
    input [7:0] planet1_char3,
    input [7:0] planet1_char4,
    input [7:0] planet1_char5,
    input [7:0] planet1_char6,
    input [7:0] planet1_char7,
    
    input [7:0] planet2_char0,
    input [7:0] planet2_char1,
    input [7:0] planet2_char2,
    input [7:0] planet2_char3,
    input [7:0] planet2_char4,
    input [7:0] planet2_char5,
    input [7:0] planet2_char6,
    input [7:0] planet2_char7,
    
    output [7:0] result
);

    reg [2:0] planet1_index;
    reg [2:0] planet2_index;
    reg planet1_valid;
    reg planet2_valid;

    always @(*) begin
        planet1_valid = 1'b0;
        planet2_valid = 1'b0;

        if (planet1_char0 == 8'd77 && planet1_char1 == 8'd101 && planet1_char2 == 8'd114 && 
            planet1_char3 == 8'd99 && planet1_char4 == 8'd117 && planet1_char5 == 8'd114 && 
            planet1_char6 == 8'd121 && planet1_char7 == 8'd0) begin
            planet1_index = 3'd0;
            planet1_valid = 1'b1;
        end
        else if (planet1_char0 == 8'd86 && planet1_char1 == 8'd101 && planet1_char2 == 8'd110 && 
                 planet1_char3 == 8'd117 && planet1_char4 == 8'd115 && planet1_char5 == 8'd0 && 
                 planet1_char6 == 8'd0 && planet1_char7 == 8'd0) begin
            planet1_index = 3'd1;
            planet1_valid = 1'b1;
        end
        else if (planet1_char0 == 8'd69 && planet1_char1 == 8'd97 && planet1_char2 == 8'd114 && 
                 planet1_char3 == 8'd116 && planet1_char4 == 8'd104 && planet1_char5 == 8'd0 && 
                 planet1_char6 == 8'd0 && planet1_char7 == 8'd0) begin
            planet1_index = 3'd2;
            planet1_valid = 1'b1;
        end
        else if (planet1_char0 == 8'd77 && planet1_char1 == 8'd97 && planet1_char2 == 8'd114 && 
                 planet1_char3 == 8'd115 && planet1_char4 == 8'd0 && planet1_char5 == 8'd0 && 
                 planet1_char6 == 8'd0 && planet1_char7 == 8'd0) begin
            planet1_index = 3'd3;
            planet1_valid = 1'b1;
        end
        else if (planet1_char0 == 8'd74 && planet1_char1 == 8'd117 && planet1_char2 == 8'd112 && 
                 planet1_char3 == 8'd105 && planet1_char4 == 8'd116 && planet1_char5 == 8'd101 && 
                 planet1_char6 == 8'd114 && planet1_char7 == 8'd0) begin
            planet1_index = 3'd4;
            planet1_valid = 1'b1;
        end
        else if (planet1_char0 == 8'd83 && planet1_char1 == 8'd97 && planet1_char2 == 8'd116 && 
                 planet1_char3 == 8'd117 && planet1_char4 == 8'd114 && planet1_char5 == 8'd110 && 
                 planet1_char6 == 8'd0 && planet1_char7 == 8'd0) begin
            planet1_index = 3'd5;
            planet1_valid = 1'b1;
        end
        else if (planet1_char0 == 8'd85 && planet1_char1 == 8'd114 && planet1_char2 == 8'd97 && 
                 planet1_char3 == 8'd110 && planet1_char4 == 8'd117 && planet1_char5 == 8'd115 && 
                 planet1_char6 == 8'd0 && planet1_char7 == 8'd0) begin
            planet1_index = 3'd6;
            planet1_valid = 1'b1;
        end
        else if (planet1_char0 == 8'd78 && planet1_char1 == 8'd101 && planet1_char2 == 8'd112 && 
                 planet1_char3 == 8'd116 && planet1_char4 == 8'd117 && planet1_char5 == 8'd110 && 
                 planet1_char6 == 8'd101 && planet1_char7 == 8'd0) begin
            planet1_index = 3'd7;
            planet1_valid = 1'b1;
        end

        if (planet2_char0 == 8'd77 && planet2_char1 == 8'd101 && planet2_char2 == 8'd114 && 
            planet2_char3 == 8'd99 && planet2_char4 == 8'd117 && planet2_char5 == 8'd114 && 
            planet2_char6 == 8'd121 && planet2_char7 == 8'd0) begin
            planet2_index = 3'd0;
            planet2_valid = 1'b1;
        end
        else if (planet2_char0 == 8'd86 && planet2_char1 == 8'd101 && planet2_char2 == 8'd110 && 
                 planet2_char3 == 8'd117 && planet2_char4 == 8'd115 && planet2_char5 == 8'd0 && 
                 planet2_char6 == 8'd0 && planet2_char7 == 8'd0) begin
            planet2_index = 3'd1;
            planet2_valid = 1'b1;
        end
        else if (planet2_char0 == 8'd69 && planet2_char1 == 8'd97 && planet2_char2 == 8'd114 && 
                 planet2_char3 == 8'd116 && planet2_char4 == 8'd104 && planet2_char5 == 8'd0 && 
                 planet2_char6 == 8'd0 && planet2_char7 == 8'd0) begin
            planet2_index = 3'd2;
            planet2_valid = 1'b1;
        end
        else if (planet2_char0 == 8'd77 && planet2_char1 == 8'd97 && planet2_char2 == 8'd114 && 
                 planet2_char3 == 8'd115 && planet2_char4 == 8'd0 && planet2_char5 == 8'd0 && 
                 planet2_char6 == 8'd0 && planet2_char7 == 8'd0) begin
            planet2_index = 3'd3;
            planet2_valid = 1'b1;
        end
        else if (planet2_char0 == 8'd74 && planet2_char1 == 8'd117 && planet2_char2 == 8'd112 && 
                 planet2_char3 == 8'd105 && planet2_char4 == 8'd116 && planet2_char5 == 8'd101 && 
                 planet2_char6 == 8'd114 && planet2_char7 == 8'd0) begin
            planet2_index = 3'd4;
            planet2_valid = 1'b1;
        end
        else if (planet2_char0 == 8'd83 && planet2_char1 == 8'd97 && planet2_char2 == 8'd116 && 
                 planet2_char3 == 8'd117 && planet2_char4 == 8'd114 && planet2_char5 == 8'd110 && 
                 planet2_char6 == 8'd0 && planet2_char7 == 8'd0) begin
            planet2_index = 3'd5;
            planet2_valid = 1'b1;
        end
        else if (planet2_char0 == 8'd85 && planet2_char1 == 8'd114 && planet2_char2 == 8'd97 && 
                 planet2_char3 == 8'd110 && planet2_char4 == 8'd117 && planet2_char5 == 8'd115 && 
                 planet2_char6 == 8'd0 && planet2_char7 == 8'd0) begin
            planet2_index = 3'd6;
            planet2_valid = 1'b1;
        end
        else if (planet2_char0 == 8'd78 && planet2_char1 == 8'd101 && planet2_char2 == 8'd112 && 
                 planet2_char3 == 8'd116 && planet2_char4 == 8'd117 && planet2_char5 == 8'd110 && 
                 planet2_char6 == 8'd101 && planet2_char7 == 8'd0) begin
            planet2_index = 3'd7;
            planet2_valid = 1'b1;
        end
    end

    reg [7:0] result_reg;
    integer i;

    always @(*) begin
        result_reg = 8'd0;

        if (planet1_valid && planet2_valid && (planet1_index != planet2_index)) begin
            if (planet1_index < planet2_index) begin
                for (i = 0; i < 8; i = i + 1) begin
                    if (i > planet1_index && i < planet2_index) begin
                        result_reg[i] = 1'b1;
                    end
                end
            end
            else begin
                for (i = 0; i < 8; i = i + 1) begin
                    if (i > planet2_index && i < planet1_index) begin
                        result_reg[i] = 1'b1;
                    end
                end
            end
        end
    end

    assign result = result_reg;

endmodule