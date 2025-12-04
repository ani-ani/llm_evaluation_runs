module color_code_verifier(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] p,
  input [15:0] palette,
  input [15:0][3:0] sequence_in,
  output reg valid,
  output reg done
);

parameter IDLE = 1'b0;
parameter VERIFY = 1'b1;

reg [1:0] state;
reg [3:0] counter;
reg [3:0] max_transitions_reg;
reg [3:0] ham_distance;
integer k;

always @(posedge clk) begin
  if (!rst_n) begin
    state <= IDLE;
    valid <= 0;
    done <= 0;
    counter <= 0;
    max_transitions_reg <= 0;
  end
  else begin
    case (state)
      IDLE: begin
        if (start) begin
          max_transitions_reg <= (1<<n) - 1;
          if ((1<<n) - 1 == 0) begin
            state <= IDLE;
            valid <= 1;
            done <= 1;
          end
          else begin
            state <= VERIFY;
            valid <= 0;
            done <= 0;
            counter <= 0;
          end
        end
        else begin
          state <= IDLE;
          valid <= 0;
          done <= 0;
          max_transitions_reg <= 0;
        end
      end
      VERIFY: begin
        if (counter < max_transitions_reg) begin
          ham_distance = 0;
          for (k = 0; k < 4; k++) begin
            ham_distance += sequence_in[counter][k] ^ sequence_in[counter+1][k];
          end

          if (ham_distance >= 16) begin
            valid <= 0;
            done <= 1;
            state <= IDLE;
          end
          else if (palette[ham_distance] == 1'b0) begin
            valid <= 0;
            done <= 1;
            state <= IDLE;
          end
          else if (counter == max_transitions_reg - 1) begin
            valid <= 1;
            done <= 1;
            state <= IDLE;
          end
          else begin
            counter <= counter + 1;
          end
        end
        else begin
          valid <= 1;
          done <= 1;
          state <= IDLE;
        end
      end
    endcase
  end
end

endmodule