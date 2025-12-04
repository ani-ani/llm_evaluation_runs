module lowercase_filter (
    input clk,
    input rst_n,
    input start,
    input [63:0] str_in,
    output [63:0] str_out,
    output [3:0] valid_len,
    output done
);
    
    reg [3:0] count;
    reg [3:0] write_ptr;
    reg [63:0] str_out_reg;
    reg [3:0] valid_len_reg;
    reg done_reg;
    
    wire [7:0] current_byte = str_in[63 - (count*8) -: 8];
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 4'b0;
            write_ptr <= 4'b0;
            str_out_reg <= 64'b0;
            valid_len_reg <= 4'b0;
            done_reg <= 1'b0;
        end else begin
            done_reg <= 1'b0;
            
            if (start) begin
                count <= 4'b0;
                write_ptr <= 4'b0;
                str_out_reg <= 64'b0;
                valid_len_reg <= 4'b0;
                
                if (!(str_in[63:56] >= 8'h61 && str_in[63:56] <= 8'h7A)) begin
                    str_out_reg[63:56] <= str_in[63:56];
                    write_ptr <= 4'b1;
                end
                count <= 4'b1;
            end else begin
                if (count < 4'd8) begin
                    if (!(current_byte >= 8'h61 && current_byte <= 8'h7A)) begin
                        str_out_reg[63 - (write_ptr*8) -: 8] <= current_byte;
                        write_ptr <= write_ptr + 4'b1;
                    end
                    count <= count + 4'b1;
                end else if (count == 4'd8) begin
                    valid_len_reg <= write_ptr;
                    done_reg <= 1'b1;
                    count <= 4'b0;
                end
            end
        end
    end
    
    assign str_out = str_out_reg;
    assign valid_len = valid_len_reg;
    assign done = done_reg;
    
endmodule