module lucky_number_supply(
  input clk, 
  input rst_n, 
  input start, 
  input [3:0] n, 
  output reg [15:0] supply_count, 
  output reg done
);

  // States
  localparam IDLE        = 3'd0;
  localparam GEN_DIGIT_1 = 3'd1;
  localparam GEN_DIGIT_2 = 3'd2;
  localparam GEN_DIGIT_3 = 3'd3;
  localparam DONE        = 3'd4;
  
  reg [2:0] state;
  reg [3:0] n_reg;
  reg [3:0] digit1, digit2, digit3;
  reg [7:0] current_value2;
  reg [11:0] prefix_2digit;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      supply_count <= 0;
      digit1 <= 0;
      digit2 <= 0;
      digit3 <= 0;
      n_reg <= 0;
      current_value2 <= 0;
      prefix_2digit <= 0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            n_reg <= n;
            digit1 <= 1;
            state <= GEN_DIGIT_1;
            supply_count <= 0;
          end
        end

        GEN_DIGIT_1: begin
          if (digit1 <= 9) begin
            digit2 <= 0;
            state <= GEN_DIGIT_2;
          end else begin
            state <= DONE;
          end
        end

        GEN_DIGIT_2: begin
          if (digit2 <= 9) begin
            current_value2 = digit1*10 + digit2;
            if ((current_value2 % 2) == 0) begin
              if (n_reg == 4'd2) begin    // n=2
                supply_count <= supply_count + 1;
              end
              else if (n_reg == 4'd3) begin  // n=3
                prefix_2digit <= current_value2;
                digit3 <= 0;
                state <= GEN_DIGIT_3;
              end
            end

            digit2 <= digit2 + 1;
            if (digit2 == 9) 
              digit1 <= digit1 + 1;
          end
          else begin
            digit1 <= digit1 + 1;
            state <= GEN_DIGIT_1;
          end
        end

        GEN_DIGIT_3: begin
          if (digit3 <= 9) begin
            if ((prefix_2digit*10 + digit3) % 3 == 0) 
              supply_count <= supply_count + 1;
            digit3 <= digit3 + 1;
          end
          else begin
            state <= GEN_DIGIT_2;
          end
        end

        DONE: begin
          done <= 1;
          if (!start) 
            state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule