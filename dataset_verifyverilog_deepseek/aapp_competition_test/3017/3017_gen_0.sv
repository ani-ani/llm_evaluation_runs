module count_power_substrings(
  input clk,              
  input rst_n,            
  input start,            
  input [15:0] n,         
  input [4:0][3:0] power_str, 
  input [2:0] substr_len, 
  output reg [16:0] count,
  output reg done
);

  typedef enum logic [1:0] {IDLE, PROCESS, DONE} state_t;
  state_t state, next_state;
  reg [15:0] k;
  wire [19:0] bcd_k;

  function automatic [19:0] bin2bcd;
    input [15:0] bin;
    reg [35:0] temp;
    integer i;
    begin
      temp = {{16{1'b0}}, bin};
      for (i=0; i<16; i=i+1) begin
        if (temp[19:16] >= 5) temp[19:16] = temp[19:16] + 3;
        if (temp[23:20] >= 5) temp[23:20] = temp[23:20] + 3;
        if (temp[27:24] >= 5) temp[27:24] = temp[27:24] + 3;
        if (temp[31:28] >= 5) temp[31:28] = temp[31:28] + 3;
        if (temp[35:32] >= 5) temp[35:32] = temp[35:32] + 3;
        temp = temp << 1;
      end
      bin2bcd = temp[35:16];
    end
  endfunction

  assign bcd_k = bin2bcd(k);

  reg match;
  always_comb begin
    match = 1'b0;
    if (substr_len >= 1 && substr_len <= 5) begin
      for (int j=0; j <= (5 - substr_len); j=j+1) begin
        if (bcd_k[19 - j*4 -: substr_len*4] == power_str[19 -: substr_len*4]) begin
          match = 1'b1;
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 17'b0;
      done <= 1'b0;
      k <= 16'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            count <= 17'b0;
            k <= 16'b0;
            done <= 1'b0;
            state <= PROCESS;
          end
        end
        PROCESS: begin
          if (k <= n) begin
            if (match) count <= count + 1'b1;
            k <= k + 1'b1;
            if ((k + 1) > n) state <= DONE;
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule