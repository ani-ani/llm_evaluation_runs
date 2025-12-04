module nsw_prime(input clk, input rst_n, input start, input [4:0] n_in, output reg [15:0] result, output reg done);
  typedef enum {IDLE, COMPUTE} state_t;
  state_t state;
  reg [15:0] prev_reg;
  reg [15:0] curr_reg;
  reg [4:0] counter;
  reg [4:0] n_target_reg;
  reg prev_start;
  
  wire start_pulse = start && !prev_start;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 16'd0;
      prev_start <= 1'b0;
      prev_reg <= 16'd0;
      curr_reg <= 16'd0;
      counter <= 5'd0;
      n_target_reg <= 5'd0;
    end else begin
      prev_start <= start;
      case (state)
        IDLE: begin
          if (start_pulse) begin
            n_target_reg <= n_in;
            if (n_in == 5'd0 || n_in == 5'd1) begin
              result <= 16'd1;
              done <= 1'b1;
            end else begin
              prev_reg <= 16'd1;
              curr_reg <= 16'd1;
              counter <= n_in - 5'd1;
              done <= 1'b0;
              state <= COMPUTE;
            end
          end
        end
        COMPUTE: begin
          if (counter == 5'd0) begin
            result <= curr_reg;
            done <= 1'b1;
            state <= IDLE;
          end else begin
            prev_reg <= curr_reg;
            curr_reg <= (2 * curr_reg) + prev_reg;
            counter <= counter - 5'd1;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule