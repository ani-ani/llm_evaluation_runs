module house_envy_solver (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [31:0] k,
  input [31:0] h0,
  input [31:0] h1,
  input [31:0] h2,
  input [31:0] h3,
  input [31:0] h4,
  input [31:0] h5,
  input [31:0] h6,
  input [31:0] h7,
  output reg [31:0] max_height,
  output reg done
);

  typedef enum {IDLE, LOAD, ITERATE, COMPLETE} state_t;
  state_t state, next_state;

  reg [2:0] n_reg;
  reg [31:0] k_reg;
  reg [6:0] iter_ctr;
  reg [2:0] house_ctr;
  reg [31:0] h[0:7];
  
  wire [31:0] left = (house_ctr == 3'd0) ? 32'd0 : h[house_ctr-1];
  wire [31:0] right = (house_ctr == n_reg) ? 32'd0 : h[house_ctr+1];
  
  wire [32:0] sum = {1'b0, left} + {1'b0, right};
  wire [31:0] avg = sum[32:1];
  wire [31:0] candidate = avg + k_reg;
  
  wire [31:0] new_h = (candidate > h[house_ctr]) ? candidate : h[house_ctr];
  
  function automatic [31:0] get_max;
    reg [31:0] tmp;
    integer i;
    begin
      tmp = h[0];
      for (i=0; i<=n_reg; i=i+1)
        if (h[i] > tmp) tmp = h[i];
      get_max = tmp;
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_height <= 32'd0;
      iter_ctr <= 7'd0;
      house_ctr <= 3'd0;
      foreach (h[i]) h[i] <= 32'd0;
    end
    else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) next_state <= LOAD;
        end

        LOAD: begin
          n_reg <= n;
          k_reg <= k;
          h[0] <= h0;
          h[1] <= h1;
          h[2] <= h2;
          h[3] <= h3;
          h[4] <= h4;
          h[5] <= h5;
          h[6] <= h6;
          h[7] <= h7;
          iter_ctr <= 7'd99;
          house_ctr <= 3'd0;
          next_state <= ITERATE;
        end

        ITERATE: begin
          h[house_ctr] <= new_h;
          
          if (house_ctr == n_reg) begin
            house_ctr <= 3'd0;
            iter_ctr <= iter_ctr - 1;
            if (iter_ctr == 7'd0) next_state <= COMPLETE;
          end
          else house_ctr <= house_ctr + 1;
        end

        COMPLETE: begin
          max_height <= get_max();
          done <= 1'b1;
          if (start) next_state <= LOAD;
          else next_state <= COMPLETE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end
endmodule