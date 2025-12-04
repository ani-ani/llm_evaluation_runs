module prime_palindrome_compare (
  input clk,
  input rst_n,
  input [15:0] p,
  input [15:0] q,
  input start,
  output reg [9:0] result,
  output reg done
);
  
  localparam IDLE = 1'b0;
  localparam RUNNING = 1'b1;
  
  reg state;
  reg [9:0] n_current;
  reg [9:0] prime_count;
  reg [9:0] pal_count;
  reg [1000:0] prime_mem;
  
  wire current_prime = (state == RUNNING && n_current <= 1000) ? prime_mem[n_current] : 1'b0;
  wire current_pal = (state == RUNNING && n_current <= 1000) ? is_pal(n_current) : 1'b0;
  wire [9:0] next_prime_count = prime_count + (current_prime ? 10'd1 : 10'd0);
  wire [9:0] next_pal_count = pal_count + (current_pal ? 10'd1 : 10'd0);
  wire [31:0] left_product = next_prime_count * q;
  wire [31:0] right_product = next_pal_count * p;
  wire condition_met = (left_product <= right_product);
  
  // Sieve initialization
  integer i, j;
  initial begin
    prime_mem = {1001{1'b1}};
    prime_mem[0] = 1'b0;
    prime_mem[1] = 1'b0;
    for (i = 2; i <= 31; i = i + 1) begin
      if (prime_mem[i]) begin
        for (j = i * i; j <= 1000; j = j + i)
          prime_mem[j] = 1'b0;
      end
    end
  end
  
  function automatic logic is_pal(input [9:0] n);
    logic [3:0] hundreds, tens, units;
    units = n % 10;
    tens = (n / 10) % 10;
    hundreds = (n / 100) % 10;
    
    if (n < 10)          return 1'b1;
    else if (n < 100)    return (units == tens);
    else if (n < 1000)   return (units == hundreds);
    else                 return 1'b0;
  endfunction
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      n_current <= 0;
      prime_count <= 0;
      pal_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      done <= 0;
      case (state)
        IDLE: begin
          if (start) begin
            state <= RUNNING;
            n_current <= 1;
            prime_count <= 0;
            pal_count <= 0;
            result <= 0;
          end
        end
        
        RUNNING: begin
          if (n_current <= 1000) begin
            if (condition_met) result <= n_current;
            prime_count <= next_prime_count;
            pal_count <= next_pal_count;
            n_current <= n_current + 1;
          end else begin
            done <= 1;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule