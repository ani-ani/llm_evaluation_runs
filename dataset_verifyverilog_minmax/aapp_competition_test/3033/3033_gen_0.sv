module digit_product_solver(
  input clk,
  input rst_n,
  input start,
  input [3:0] B,
  input [15:0] N,
  output reg [31:0] X,
  output reg impossible,
  output reg done
);

reg [19:0] addr_reg;
reg read_en;
wire [32:0] rom_data;

// ROM: 2^20 entries, each 33 bits
reg [32:0] rom [0:(1<<20)-1];
assign rom_data = (read_en) ? rom[addr_reg] : 33'b0;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    X <= 0;
    impossible <= 0;
    done <= 0;
    addr_reg <= 0;
    read_en <= 0;
  end else if (start) begin
    addr_reg <= {B, N};
    read_en <= 1;
    done <= 0;
  end else if (read_en) begin
    X <= rom_data[31:0];
    impossible <= rom_data[32];
    done <= 1;
    read_en <= 0;
  end else begin
    read_en <= 0;
  end
end

endmodule