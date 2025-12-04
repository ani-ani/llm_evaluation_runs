module min_energy_calculator(
  input clk,               
  input rst_n,             
  input start,             
  input [2:0] n,           
  input [15:0] a0, a1, a2, a3, a4, a5, a6, a7, 
  input [3:0] k_query,     
  output reg [31:0] min_energy, 
  output reg ready,        
  output reg valid         
);

  typedef enum {IDLE, LOAD, COMPUTE, READY, OUTPUT} state_t;
  state_t state, next_state;
  reg [31:0] dp [1:16];
  reg [3:0] counter;
  reg [31:0] temp_min;
  reg [3:0] current_k;
  reg [3:0] registered_k;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      ready <= 1'b0;
      valid <= 1'b0;
      for (int i=1; i<=16; i=i+1) dp[i] <= 32'd0;
      counter <= 4'd0;
      temp_min <= 32'd0;
      current_k <= 4'd0;
      registered_k <= 4'd0;
      min_energy <= 32'd0;
    end else begin
      state <= next_state;
      registered_k <= (state == READY) ? k_query : registered_k;

      case (state)
        IDLE: begin
          if (start) next_state = LOAD;
        end

        LOAD: begin
          dp[1] <= {16'b0, a0};
          dp[2] <= {16'b0, a1};
          dp[3] <= {16'b0, a2};
          dp[4] <= {16'b0, a3};
          dp[5] <= {16'b0, a4};
          dp[6] <= {16'b0, a5};
          dp[7] <= {16'b0, a6};
          dp[8] <= {16'b0, a7};
          next_state = COMPUTE;
          counter <= 4'd0;
          temp_min <= 32'hFFFF_FFFF;
          current_k <= 4'd9;
        end

        COMPUTE: begin
          if (counter[0] == 1'b0) begin
            temp_min <= 32'hFFFF_FFFF;
            case (current_k)
              9: begin
                temp_min <= (dp[1] + dp[8] < temp_min) ? dp[1] + dp[8] : temp_min;
                temp_min <= (dp[2] + dp[7] < temp_min) ? dp[2] + dp[7] : temp_min;
              end
              10: begin
                temp_min <= (dp[1] + dp[9] < temp_min) ? dp[1] + dp[9] : temp_min;
                temp_min <= (dp[2] + dp[8] < temp_min) ? dp[2] + dp[8] : temp_min;
                temp_min <= (dp[3] + dp[7] < temp_min) ? dp[3] + dp[7] : temp_min;
              end
              11: begin
                temp_min <= (dp[1] + dp[10] < temp_min) ? dp[1] + dp[10] : temp_min;
                temp_min <= (dp[2] + dp[9] < temp_min) ? dp[2] + dp[9] : temp_min;
                temp_min <= (dp[3] + dp[8] < temp_min) ? dp[3] + dp[8] : temp_min;
              end
              12: begin
                temp_min <= (dp[1] + dp[11] < temp_min) ? dp[1] + dp[11] : temp_min;
                temp_min <= (dp[2] + dp[10] < temp_min) ? dp[2] + dp[10] : temp_min;
                temp_min <= (dp[3] + dp[9] < temp_min) ? dp[3] + dp[9] : temp_min;
                temp_min <= (dp[4] + dp[8] < temp_min) ? dp[4] + dp[8] : temp_min;
              end
              13: begin
                temp_min <= (dp[1] + dp[12] < temp_min) ? dp[1] + dp[12] : temp_min;
                temp_min <= (dp[2] + dp[11] < temp_min) ? dp[2] + dp[11] : temp_min;
                temp_min <= (dp[3] + dp[10] < temp_min) ? dp[3] + dp[10] : temp_min;
                temp_min <= (dp[4] + dp[9] < temp_min) ? dp[4] + dp[9] : temp_min;
              end
              14: begin
                temp_min <= (dp[1] + dp[13] < temp_min) ? dp[1] + dp[13] : temp_min;
                temp_min <= (dp[2] + dp[12] < temp_min) ? dp[2] + dp[12] : temp_min;
                temp_min <= (dp[3] + dp[11] < temp_min) ? dp[3] + dp[11] : temp_min;
                temp_min <= (dp[4] + dp[10] < temp_min) ? dp[4] + dp[10] : temp_min;
                temp_min <= (dp[5] + dp[9] < temp_min) ? dp[5] + dp[9] : temp_min;
              end
              15: begin
                temp_min <= (dp[1] + dp[14] < temp_min) ? dp[1] + dp[14] : temp_min;
                temp_min <= (dp[2] + dp[13] < temp_min) ? dp[2] + dp[13] : temp_min;
                temp_min <= (dp[3] + dp[12] < temp_min) ? dp[3] + dp[12] : temp_min;
                temp_min <= (dp[4] + dp[11] < temp_min) ? dp[4] + dp[11] : temp_min;
                temp_min <= (dp[5] + dp[10] < temp_min) ? dp[5] + dp[10] : temp_min;
                temp_min <= (dp[6] + dp[9] < temp_min) ? dp[6] + dp[9] : temp_min;
              end
              16: begin
                temp_min <= (dp[1] + dp[15] < temp_min) ? dp[1] + dp[15] : temp_min;
                temp_min <= (dp[2] + dp[14] < temp_min) ? dp[2] + dp[14] : temp_min;
                temp_min <= (dp[3] + dp[13] < temp_min) ? dp[3] + dp[13] : temp_min;
                temp_min <= (dp[4] + dp[12] < temp_min) ? dp[4] + dp[12] : temp_min;
                temp_min <= (dp[5] + dp[11] < temp_min) ? dp[5] + dp[11] : temp_min;
                temp_min <= (dp[6] + dp[10] < temp_min) ? dp[6] + dp[10] : temp_min;
                temp_min <= (dp[7] + dp[9] < temp_min) ? dp[7] + dp[9] : temp_min;
              end
            endcase
          end else begin
            case (current_k)
              9: begin
                temp_min <= (dp[3] + dp[6] < temp_min) ? dp[3] + dp[6] : temp_min;
                temp_min <= (dp[4] + dp[5] < temp_min) ? dp[4] + dp[5] : temp_min;
                dp[9] <= temp_min;
              end
              10: begin
                temp_min <= (dp[4] + dp[6] < temp_min) ? dp[4] + dp[6] : temp_min;
                temp_min <= (dp[5] + dp[5] < temp_min) ? dp[5] + dp[5] : temp_min;
                dp[10] <= temp_min;
              end
              11: begin
                temp_min <= (dp[4] + dp[7] < temp_min) ? dp[4] + dp[7] : temp_min;
                temp_min <= (dp[5] + dp[6] < temp_min) ? dp[5] + dp[6] : temp_min;
                dp[11] <= temp_min;
              end
              12: begin
                temp_min <= (dp[5] + dp[7] < temp_min) ? dp[5] + dp[7] : temp_min;
                temp_min <= (dp[6] + dp[6] < temp_min) ? dp[6] + dp[6] : temp_min;
                dp[12] <= temp_min;
              end
              13: begin
                temp_min <= (dp[5] + dp[8] < temp_min) ? dp[5] + dp[8] : temp_min;
                temp_min <= (dp[6] + dp[7] < temp_min) ? dp[6] + dp[7] : temp_min;
                dp[13] <= temp_min;
              end
              14: begin
                temp_min <= (dp[6] + dp[8] < temp_min) ? dp[6] + dp[8] : temp_min;
                temp_min <= (dp[7] + dp[7] < temp_min) ? dp[7] + dp[7] : temp_min;
                dp[14] <= temp_min;
              end
              15: begin
                temp_min <= (dp[7] + dp[8] < temp_min) ? dp[7] + dp[8] : temp_min;
                dp[15] <= temp_min;
              end
              16: begin
                temp_min <= (dp[8] + dp[8] < temp_min) ? dp[8] + dp[8] : temp_min;
                dp[16] <= temp_min;
              end
            endcase
            current_k <= current_k + 1;
          end

          if (counter == 4'd15) next_state = READY;
          counter <= counter + 1;
        end

        READY: begin
          ready <= 1'b1;
          if (k_query != registered_k) begin
            next_state = OUTPUT;
          end
        end

        OUTPUT: begin
          min_energy <= dp[registered_k];
          valid <= 1'b1;
          next_state = READY;
        end

        default: next_state = IDLE;
      endcase
    end
  end

  always_comb begin
    case (state)
      IDLE: next_state = start ? LOAD : IDLE;
      LOAD: next_state = COMPUTE;
      COMPUTE: next_state = (counter == 4'd15) ? READY : COMPUTE;
      READY: next_state = (k_query != registered_k) ? OUTPUT : READY;
      OUTPUT: next_state = READY;
      default: next_state = IDLE;
    endcase
  end

endmodule