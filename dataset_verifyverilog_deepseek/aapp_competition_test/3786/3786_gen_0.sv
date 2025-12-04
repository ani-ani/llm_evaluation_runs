module top_module ( 
    input wire clk, 
    input wire reset, 
    input wire [7:0] data_in, 
    output reg [7:0] data_out 
); 

    // Internal register 
    reg [7:0] internal_reg; 

    // Always block for sequential logic 
    always @(posedge clk or posedge reset) begin 
        if (reset) begin 
            internal_reg <= 8'h00; 
            data_out <= 8'h00; 
        end 
        else begin 
            internal_reg <= data_in; 
            data_out <= internal_reg; 
        end 
    end 

endmodule